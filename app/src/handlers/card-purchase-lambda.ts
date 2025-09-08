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
    const dynamoDBService = new DynamoDBService();
    const sqsService = new SimpleQueueService();
    const TABLE_NAME = process.env.DYNAMODB_TRANSACTION_TABLE || "";
    const QUEUE_URL = process.env.NOTIFICATIONS_EMAIL_SQS_URL || "";

    const payload: IPurchasePayloadToDB = {
      uuid: uuid(),
      cardId,
      amount,
      merchant,
      type: "PURCHASE",
      createdAt: new Date().toISOString(),
    };

    const res = await dynamoDBService.saveItem({
      TableName: TABLE_NAME,
      Item: payload,
    });

    await sqsService.sendMessage({
      queueUrl: QUEUE_URL,
      body: {
        type: "TRANSACTION.PURCHASE",
        data: {
          date: new Date().toISOString(),
          merchant,
          cardId,
          amount: amount,
        },
      },
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ ...payload }),
      headers: {
        "Content-type": "application/json",
      },
    };

  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error }),
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
