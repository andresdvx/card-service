import middy from "@middy/core";
import type { APIGatewayEvent, APIGatewayProxyResult } from "aws-lambda";
import { v4 as uuid } from "uuid";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";
import { SimpleQueueService } from "../simple-queue-service/simple-queue.service.js";

interface IPurchasePayload {
  merchant: string;
  cardId: string;
  amount: number;
}

interface IPurchasePayloadToDB extends IPurchasePayload {
  uuid: string;
  type: string;
  createdAt: string;
}

const cardPurchaseHandler = async (
  event: APIGatewayEvent
): Promise<APIGatewayProxyResult> => {
  try {
    const body = JSON.parse(event.body || "{}");
    const { merchant, cardId, amount }: IPurchasePayload = body;
    
    // Validar que el monto sea positivo
    if (amount <= 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "Amount must be greater than 0" }),
        headers: { "Content-type": "application/json" }
      };
    }

    const dynamoDBService = new DynamoDBService();
    const sqsService = new SimpleQueueService();
    const CARDS_TABLE_NAME = process.env.DYNAMODB_CARDS_TABLE || "card-table";
    const TRANSACTION_TABLE_NAME = process.env.DYNAMODB_TRANSACTION_TABLE || "";
    const QUEUE_URL = process.env.NOTIFICATIONS_EMAIL_SQS_URL || "";

    const cardResponse = await dynamoDBService.getItem({
      TableName: CARDS_TABLE_NAME,
      Key: {
        uuid: cardId
      }
    });

    if (!cardResponse.Item) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: "Card not found" }),
        headers: { "Content-type": "application/json" }
      };
    }

    const card = cardResponse.Item;
    const currentBalance = card.balance || 0;

    if (currentBalance < amount) {
      return {
        statusCode: 400,
        body: JSON.stringify({ 
          error: "Insufficient balance",
          currentBalance,
          requestedAmount: amount
        }),
        headers: { "Content-type": "application/json" }
      };
    }

    const newBalance = currentBalance - amount;

    await dynamoDBService.updateItem({
      TableName: CARDS_TABLE_NAME,
      Key: {
        uuid: cardId
      },
      UpdateExpression: "SET balance = :newBalance",
      ExpressionAttributeValues: {
        ":newBalance": newBalance
      }
    });

    const transactionPayload: IPurchasePayloadToDB = {
      uuid: uuid(),
      cardId,
      amount,
      merchant,
      type: "PURCHASE",
      createdAt: new Date().toISOString(),
    };

    const res = await dynamoDBService.saveItem({
      TableName: TRANSACTION_TABLE_NAME,
      Item: transactionPayload,
    });

    // 6. Enviar notificación a SQS
    await sqsService.sendMessage({
      queueUrl: QUEUE_URL,
      body: {
        type: "TRANSACTION.PURCHASE",
        data: {
          date: new Date().toISOString(),
          merchant,
          cardId,
          amount: amount,
          previousBalance: currentBalance,
          newBalance: newBalance
        },
      },
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ 
        transaction: transactionPayload,
        cardBalance: {
          previous: currentBalance,
          current: newBalance,
          amountCharged: amount
        }
      }),
      headers: {
        "Content-type": "application/json",
      },
    };

  } catch (error) {
    console.error("Error processing purchase:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ 
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error"
      }),
      headers: {
        "Content-type": "application/json",
      },
    };
  }
};

export const handler = middy<APIGatewayEvent, APIGatewayProxyResult>(
  cardPurchaseHandler
);

// {
// 	"type": "TRANSACTION.PURCHASE",
// 	"data": {
// 		"date": "2025-08-27T17:27:00.000Z",
// 		"merchant": "Tienda patito feliz",
// 		"cardId": "39fe6315-2dd5-4f2d-9160-22f1c96a05c8",
// 		"amount": 1000,
// 	}
// }
