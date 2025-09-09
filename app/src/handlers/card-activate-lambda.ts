import type { APIGatewayEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";
import { SimpleQueueService } from "../simple-queue-service/simple-queue.service.js";

export const handler = async (
  event: APIGatewayEvent
): Promise<APIGatewayProxyResult> => {
  try {
    const body = JSON.parse(event.body || "{}");
    const { userId } = body;
    const CARD_TABLE_NAME = process.env.DYNAMODB_CARDS_TABLE || "card-table";
    const TRANSACTION_TABLE_NAME =
      process.env.DYNAMODB_TRANSACTION_TABLE || "transaction-table";
    const QUEUE_URL = process.env.NOTIFICATIONS_EMAIL_SQS_URL || "";

    if (!userId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "userId is required" }),
      };
    }

    const dynamoDBService = new DynamoDBService();
    const simpleQueueService = new SimpleQueueService();

    // Buscar tarjeta DEBIT del usuario
    const debitCardsRes = await dynamoDBService.scanTable({
      TableName: CARD_TABLE_NAME,
      FilterExpression: "user_id = :userId AND #type = :type",
      ExpressionAttributeValues: {
        ":userId": userId,
        ":type": "DEBIT",
      },
      ExpressionAttributeNames: {
        "#type": "type",
      },
    });

    const debitCard = debitCardsRes.Items?.[0];

    if (!debitCard) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: "No debit card found for user" }),
      };
    }

    // Buscar transacciones de la tarjeta DEBIT
    const transactionsRes = await dynamoDBService.scanTable({
      TableName: TRANSACTION_TABLE_NAME,
      FilterExpression: "cardId = :cardId",
      ExpressionAttributeValues: {
        ":cardId": debitCard.uuid,
      },
    });

    if ((transactionsRes.Items?.length || 0) < 10) {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: "Not enough transactions to activate credit card",
        }),
      };
    }

    // Buscar tarjeta CREDIT del usuario en estado PENDING
    const creditCardsRes = await dynamoDBService.scanTable({
      TableName: CARD_TABLE_NAME,
      FilterExpression:
        "user_id = :userId AND #type = :type AND #status = :status",
      ExpressionAttributeValues: {
        ":userId": userId,
        ":type": "CREDIT",
        ":status": "PENDING",
      },
      ExpressionAttributeNames: {
        "#type": "type",
        "#status": "status",
      },
    });

    const creditCard = creditCardsRes.Items?.[0];

    if (!creditCard) {
      return {
        statusCode: 404,
        body: JSON.stringify({
          error: "No pending credit card found for user",
        }),
      };
    }

    // Activar la tarjeta de crédito
    await dynamoDBService.updateItem({
      TableName: CARD_TABLE_NAME,
      Key: { uuid: creditCard.uuid },
      UpdateExpression: "SET #status = :activated",
      ExpressionAttributeValues: { ":activated": "ACTIVATED" },
      ExpressionAttributeNames: { "#status": "status" },
    });

    await simpleQueueService.sendMessage({
      queueUrl: QUEUE_URL,
      body: {
        type: "CARD.ACTIVATE",
        data: {
          date: new Date().toISOString(),
          type: "CREDIT",
          amount: creditCard.balance,
        },
      },
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Credit card activated" }),
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Internal server error",
        details: error instanceof Error ? error.message : error,
      }),
    };
  }
};
