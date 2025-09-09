import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";

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

  async updateItem(params: { 
    TableName: string; 
    Key: Record<string, any>; 
    UpdateExpression: string; 
    ExpressionAttributeValues: Record<string, any>;
    ExpressionAttributeNames?: Record<string, string>;
  }): Promise<any> {
    try {
      const res = await this.client.send(
        new UpdateCommand({
          TableName: params.TableName,
          Key: params.Key,
          UpdateExpression: params.UpdateExpression,
          ExpressionAttributeValues: params.ExpressionAttributeValues,
          ExpressionAttributeNames: params.ExpressionAttributeNames,
          ReturnValues: "ALL_NEW"
        })
      );
      return res;
    } catch (error) {
      console.error("Error updating item in DynamoDB:", error);
      throw error;
    }
  }
}
