import type { DynamoDBService } from "../dynamodb/dynamodb.service.js";
import { v4 as uuid } from "uuid";

export interface ICard {
  uuid: string;
  user_id: string;
  type: "DEBIT" | "CREDIT";
  status: "PENDING" | "ACTIVATED";
  balance: number;
  createdAt: string; 
}

export class CardsService {
  private readonly TABLE_NAME: string;
  private readonly dynamoDBService: DynamoDBService;

  constructor(dynamoDBService: DynamoDBService) {
    this.dynamoDBService = dynamoDBService;
    this.TABLE_NAME = process.env.DYNAMODB_CARDS_TABLE!;
  }

  async saveDebitCard(userId: string) {
    try {
      const card: ICard = {
        uuid: uuid(),
        user_id: userId,
        type: "DEBIT",
        status: "ACTIVATED",
        balance: 0,
        createdAt: new Date().toISOString(),
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
        balance: +this.getRandomCreditScore(),
        createdAt: new Date().toISOString(),
      };

      return await this.dynamoDBService.saveItem({
        TableName: this.TABLE_NAME,
        Item: card,
      });

    } catch (error) {
      console.error("Error saving credit card at CardsService:", error);
    }
  }

  private getRandomCreditScore() {
    const score = Math.floor(Math.random() * 101);
    const amount = 100 + (score / 100) * (10000000 - 100);
    return amount;
  }
}
