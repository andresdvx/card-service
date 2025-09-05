import type { DynamoDBService } from "../dynamodb/dynamodb.service.js";
import { v4 as uuid } from "uuid";

export interface ICard {
  uuid: string;
  user_id: string;
  type: "DEBIT" | "CREDIT";
  status: "PENDING" | "ACTIVATED";
  balance: number;
  createdAt: Date;
}

export class CardsService {
  private readonly TABLE_NAME = "card-table";
  private readonly dynamoDBService: DynamoDBService;

  constructor(dynamoDBService: DynamoDBService) {
    this.dynamoDBService = dynamoDBService;
  }

  async saveDebitCard(userId: string) {
    try {
      const card: ICard = {
        uuid: uuid(),
        user_id: userId,
        type: "DEBIT",
        status: "ACTIVATED",
        balance: 0,
        createdAt: new Date(),
      };
      return await this.dynamoDBService.saveItem({
        TableName: this.TABLE_NAME,
        Item: card,
      });
    } catch (error) {
      console.error("Error saving debit card at CardsService:", error);
    }
  }

  async saveCreditCard(userId: string) {
    try {
      const card: ICard = {
        uuid: uuid(),
        user_id: userId,
        type: "CREDIT",
        status: "PENDING",
        balance: 1000,
        createdAt: new Date(),
      };
      return await this.dynamoDBService.saveItem({
        TableName: this.TABLE_NAME,
        Item: card,
      });
    } catch (error) {
      console.error("Error saving credit card at CardsService:", error);
    }
  }
}
