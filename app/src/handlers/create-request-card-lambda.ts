import middy from "@middy/core";
import { type SQSEvent, type SQSBatchResponse } from "aws-lambda";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";
import { CardsService } from "../services/cards/cards.service.js";

interface IBatchItemFailure {
  itemIdentifier: string;
}

const sqsProcessor = async (event: SQSEvent): Promise<SQSBatchResponse> => {
  const batchItemFailures: IBatchItemFailure[] = [];
  const dynamoDBService = new DynamoDBService();
  const cardService = new CardsService(dynamoDBService);

  for (const record of event.Records) {
    try {
      const { userId, request } = JSON.parse(record.body);

      switch (request) {
        case "CREDIT":
          const credit = await cardService.saveCreditCard(userId);
          console.log("Credit card created: ", credit);
          break;
        case "DEBIT":
          const debit = await cardService.saveDebitCard(userId);
          console.log("Debit card created: ", debit);
          break;
        default:
          throw new Error(`Message Type Unrecognized: ${request}`);
      }

      console.log(`Successfully processed record: ${record.messageId}`);
    } catch (error) {
      console.error(`Error processing record ${record.messageId}:`, error);
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }

  return {
    batchItemFailures: batchItemFailures,
  };
};

export const handler = middy<SQSEvent, SQSBatchResponse>(sqsProcessor);
