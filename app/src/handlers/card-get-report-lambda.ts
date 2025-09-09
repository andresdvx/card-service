import type { APIGatewayEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";
import { S3Service } from "../services/s3/s3.service.js";
import { GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { SimpleQueueService } from "../simple-queue-service/simple-queue.service.js";

export const handler = async (
  event: APIGatewayEvent
): Promise<APIGatewayProxyResult> => {
  try {
    const body = JSON.parse(event.body || "{}");
    const TRANSACTION_TABLE_NAME = process.env.DYNAMODB_TRANSACTION_TABLE!;
    const S3_BUCKET = process.env.S3_BUCKET_NAME!;
    const CARD_TABLE_NAME = process.env.DYNAMODB_CARDS_TABLE!;
    const NOTIFICATIONS_EMAIL_SQS_URL =
      process.env.NOTIFICATIONS_EMAIL_SQS_URL!;
    const cardId = event.pathParameters?.card_id;
    const { start, end } = body;

    if (!start || !end || !cardId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "start, end and card_id are required" }),
      };
    }

    const dynamoDBService = new DynamoDBService();
    const s3Service = new S3Service(S3_BUCKET);
    const sqsService = new SimpleQueueService();

    const cardRes = await dynamoDBService.getItem({
      TableName: CARD_TABLE_NAME,
      Key: { uuid: cardId },
    });
    if (!cardRes.Item) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: "Card not found" }),
      };
    }

    const transactionsRes = await dynamoDBService.scanTable({
      TableName: TRANSACTION_TABLE_NAME,
      FilterExpression:
        "cardId = :cardId AND createdAt BETWEEN :start AND :end",
      ExpressionAttributeValues: {
        ":cardId": cardId,
        ":start": start,
        ":end": end,
      },
    });

    const transactions = transactionsRes.Items || [];

    const fileContent = transactions
      .map((tx: Record<string, any>) => JSON.stringify(tx))
      .join("\n");
    const fileName = `report-${cardId}-${Date.now()}.txt`;

    await s3Service.uploadTxtFile(fileName, fileContent);

    const command = new GetObjectCommand({
      Bucket: S3_BUCKET,
      Key: fileName,
    });

    const signedUrl = await getSignedUrl(s3Service["client"], command, {
      expiresIn: 3600,
    });

    await sqsService.sendMessage({
      queueUrl: NOTIFICATIONS_EMAIL_SQS_URL,
      body: {
        type: "REPORT.ACTIVITY",
        data: {
          date: new Date().toISOString(),
          url: signedUrl,
        },
      },
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ url: signedUrl }),
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
