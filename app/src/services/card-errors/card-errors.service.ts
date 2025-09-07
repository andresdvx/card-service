import type { DynamoDBService } from "../dynamodb/dynamodb.service.js";
import { v4 as uuid } from "uuid";

export class CardErrorsService {
  private readonly TABLE_NAME: string;
  private readonly dynamoDBService: DynamoDBService;

  constructor(dynamoDBService: DynamoDBService) {
    this.dynamoDBService = dynamoDBService;
    this.TABLE_NAME = process.env.DYNAMODB_FAILED_REQUESTS_TABLE!;
  }

  async saveDqlEventToDB(messageId: string, payload: any) {
    try {
      const errorItem = {
        uuid: uuid(),
        itemIdentifier: messageId,
        payload: JSON.stringify(payload),
        timestamp: new Date().toISOString(),
      };

      return await this.dynamoDBService.saveItem({
        TableName: this.TABLE_NAME,
        Item: errorItem,
      });

    } catch (error) {
      console.error("Error saving error item:", error);
      throw new Error("Error saving error item");
    }
  }
}
