import middy from "@middy/core";
import type { APIGatewayEvent, APIGatewayProxyResult } from "aws-lambda";
import { v4 as uuid } from "uuid";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";

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
    const TABLE_NAME = process.env.DYNAMODB_TRANSACTION_TABLE || "";

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

    console.log(res);

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


