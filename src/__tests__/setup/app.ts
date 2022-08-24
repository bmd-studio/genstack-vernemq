import { assignIn } from 'lodash';
import { GenericContainer, Network, StartedNetwork, StartedTestContainer } from 'testcontainers';
import * as mqtt from 'mqtt';

const MQTT_INTERNAL_PORT = 1883;
const WS_INTERNAL_PORT = 8080;

const VERNEMQ_DOCKER_IMAGE = 'ghcr.io/bmd-studio/genstack-vernemq:latest';

const MQTT_ADMIN_USERNAME = 'admin';
const MQTT_ADMIN_SECRET = 'password';

let network: StartedNetwork;
let vernemqContainer: StartedTestContainer;

const setupTestContainer = async(): Promise<void> => {
  network = await new Network()
    .start();

  vernemqContainer = await new GenericContainer(VERNEMQ_DOCKER_IMAGE)
    .withNetworkMode(network.getName())
    .withExposedPorts(MQTT_INTERNAL_PORT, WS_INTERNAL_PORT)
    .withEnv('MQTT_ADMIN_USERNAME', MQTT_ADMIN_USERNAME)
    .withEnv('MQTT_ADMIN_SECRET', MQTT_ADMIN_SECRET)
    .withEnv('DOCKER_VERNEMQ_ALLOW_ANONYMOUS', 'on')
    .withEnv('DOCKER_VERNEMQ_ACCEPT_EULA', 'yes')
    .start();
};

const shutdownContainers = async(): Promise<void> => {
  await vernemqContainer?.stop();
};

const setupEnv = async (): Promise<void> => {
  assignIn(process.env, {
    VERNEMQ_MQTT_PORT: vernemqContainer?.getMappedPort(MQTT_INTERNAL_PORT),
    VERNEMQ_WS_PORT: vernemqContainer?.getMappedPort(WS_INTERNAL_PORT),
  });
};

export const getMqttClient = async(): Promise<mqtt.Client> => {
  const { VERNEMQ_MQTT_PORT = String(MQTT_INTERNAL_PORT) } = process.env;
  const url = `mqtt://localhost`;
  const client = mqtt.connect(url, {
    port: parseInt(VERNEMQ_MQTT_PORT),
    username: MQTT_ADMIN_USERNAME,
    password: MQTT_ADMIN_SECRET,
  });

  return new Promise((resolve, reject) => {
    client.on('connect', () => {
      resolve(client);
    });
    client.on('error', () => {
      reject();
    });
  });
};

export const setupTestApp = async (): Promise<void> => {
  await setupTestContainer();
  await setupEnv();
};

export const shutdownTestApp = async (): Promise<void> => {
  await shutdownContainers();
};
