import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

export class DynamoDBService {
  private client: DynamoDBDocumentClient;

  constructor() {
    this.client = DynamoDBDocumentClient.from(new DynamoDBClient({}), {
      marshallOptions: {
        convertClassInstanceToMap: true,
        removeUndefinedValues: true,
      },
    });
  }

  async saveItem(item: { TableName: string; Item: Record<string, any> }): Promise<any> {
    try {
      const res = await this.client.send(
        new PutCommand({
          TableName: item.TableName,
          Item: item.Item,
        })
      );
      return res;
    } catch (error) {
      console.error("Error saving item to DynamoDB:", error);
      throw error;
    }
  }
}
