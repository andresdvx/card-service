import { SendMessageCommand, SQSClient } from "@aws-sdk/client-sqs";

interface ISimpleQueueService {
  queueUrl: string;
  body: Record<string, any>;
}

export class SimpleQueueService {
  private sqsClient: SQSClient;

  constructor() {
    this.sqsClient = new SQSClient({});
  }

  async sendMessage(message: ISimpleQueueService): Promise<void> {
    const params = {
      QueueUrl: message.queueUrl,
      MessageBody: JSON.stringify(message.body),
    };

    try {
      await this.sqsClient.send(new SendMessageCommand(params));
    } catch (error) {
      console.error("Error sending message to SQS:", error);
      throw error;
    }
  }
}

