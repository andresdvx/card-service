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
    const cardId = event.pathParameters?.card_id;
    
    if (!cardId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "cardId is required" }),
        headers: { "Content-type": "application/json" }
      };
    }

    const dynamoDBService = new DynamoDBService();
    const sqsService = new SimpleQueueService();
    const CARD_TABLE_NAME = process.env.DYNAMODB_CARDS_TABLE || "";
    const TRANSACTION_TABLE_NAME = process.env.DYNAMODB_TRANSACTION_TABLE || "";
    const QUEUE_URL = process.env.NOTIFICATIONS_EMAIL_SQS_URL || "";

    const cardResponse = await dynamoDBService.getItem({
      TableName: CARD_TABLE_NAME,
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

    if (card.status !== "ACTIVATED") {
      return {
        statusCode: 400,
        body: JSON.stringify({ 
          error: "Card is not activated",
          cardStatus: card.status,
          message: "Only activated cards can receive transactions"
        }),
        headers: { "Content-type": "application/json" }
      };
    }

    const currentBalance = card.balance || 0;

    const newBalance = currentBalance + amount;

    const updatedCard = await dynamoDBService.updateItem({
      TableName: CARD_TABLE_NAME,
      Key: {
        uuid: cardId
      },
      UpdateExpression: "SET balance = :newBalance",
      ExpressionAttributeValues: {
        ":newBalance": newBalance
      }
    });

    const transactionPayload = {
      uuid: uuid(),
      cardId,
      amount,
      merchant,
      type: "SAVING",
      createdAt: new Date().toISOString(),
    };

    await dynamoDBService.saveItem({
      TableName: TRANSACTION_TABLE_NAME,
      Item: transactionPayload,
    });

    await sqsService.sendMessage({
      queueUrl: QUEUE_URL,
      body: {
        type: "TRANSACTION.SAVE",
        data: {
          date: new Date().toISOString(),
          merchant,
          amount: amount,
        },
      },
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ 
        message: "Transaction processed successfully",
        transaction: transactionPayload,
        updatedCard: updatedCard.Attributes
      }),
      headers: {
        "Content-type": "application/json",
      },
    };
  } catch (error) {
    console.error("Error processing transaction:", error);
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
  cardTransactionSaveHandler
);
