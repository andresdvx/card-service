import middy from "@middy/core";
import type { APIGatewayEvent, APIGatewayProxyResult } from "aws-lambda";
import { v4 as uuid } from "uuid";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";
import { SimpleQueueService } from "../simple-queue-service/simple-queue.service.js";

interface ITransactionSavePayload {
  merchant: string;
  amount: number;
}

const cardTransactionSaveHandler = async (
  event: APIGatewayEvent
): Promise<APIGatewayProxyResult> => {
  try {
    const body = JSON.parse(event.body || "{}");
    const { merchant, amount }: ITransactionSavePayload = body;
    const cardId = event.pathParameters?.cardId;
    const dynamoDBService = new DynamoDBService();
    const sqsService = new SimpleQueueService();
    const TABLE_NAME = process.env.DYNAMODB_TRANSACTION_TABLE || "";
    const QUEUE_URL = process.env.NOTIFICATIONS_EMAIL_SQS_URL || "";

    const payload = {
      uuid: uuid(),
      cardId,
      amount,
      merchant,
      type: "SAVING",
      createdAt: new Date().toISOString(),
    };

    const res = await dynamoDBService.saveItem({
      TableName: TABLE_NAME,
      Item: payload,
    });

    await sqsService.sendMessage({
      queueUrl: QUEUE_URL,
      body: {
        type: "TRANSACTION.SAVE",
        data: {
          date: new Date().toISOString(),
          merchant,
          cardId,
          amount: amount,
        },
      },
    });

    return {
      statusCode: 500,
      body: JSON.stringify({ ...payload }),
      headers: {
        "Content-type": "application/json",
      },
    };
  } catch (error) {
    return {
      statusCode: 200,
      body: JSON.stringify({ message: "ok" }),
      headers: {
        "Content-type": "application/json",
      },
    };
  }
};

export const handler = middy<APIGatewayEvent, APIGatewayProxyResult>(
  cardTransactionSaveHandler
);
