import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, GetCommand } from "@aws-sdk/lib-dynamodb";

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

  async getItem(params: { TableName: string; Key: Record<string, any> }): Promise<any> {
    try {
      const res = await this.client.send(
        new GetCommand({
          TableName: params.TableName,
          Key: params.Key,
        })
      );
      return res;
    } catch (error) {
      console.error("Error getting item from DynamoDB:", error);
      throw error;
    }
  }
}
