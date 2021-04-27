import { setupTestApp, shutdownTestApp, getMqttClient } from '../setup/app';

describe('events', () => {
  beforeAll(async () => {
    await setupTestApp();
  });
  afterAll(async () => {
    await shutdownTestApp();
  });

  it('should send and receive MQTT event', async () => {
    const testTopic = 'test/test';
    const testPayload = {
      value: 'test-payload',
    };
    const mqttClient = await getMqttClient();

    // wrap in promise because the MQTT client works with callbacks
    return new Promise<void>((resolve) => {
      mqttClient?.on('message', (topic: string, payload: string) => {
        const parsedPayload = JSON.parse(payload.toString());
  
        // skip other topics
        // this allows other tests to run in parallel in the future
        if (topic !== testTopic) {
          return;
        }

        expect(parsedPayload).toEqual(testPayload);
        resolve();
      });
      mqttClient?.subscribe(testTopic, () => {
        mqttClient?.publish(testTopic, JSON.stringify(testPayload));
      });      
    });
  });
});