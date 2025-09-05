import middy from "@middy/core";
import { type SQSEvent } from "aws-lambda";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";
import { CardsService } from "../services/cards/cards.service.js";

interface IBatchItemFailure {
  itemIdentifier: string;
}

const sqsProcessor = async (event: SQSEvent) => {
  const batchItemFailures: IBatchItemFailure[] = [];
  const dynamoDBService = new DynamoDBService();
  const cardService = new CardsService(dynamoDBService);

  for (const record of event.Records) {
    try {
      const { userId, request } = JSON.parse(record.body);
      switch (request) {
        case "CREDIT":
          const credit = await cardService.saveCreditCard(userId);
          console.log('credit: ', credit);
          break;
        case "DEBIT":
          const debit = await cardService.saveDebitCard(userId);
          console.log('debit: ', debit);
          break;
        default:
          throw new Error("Message Type Unrecognized");
      }
    } catch (error) {
      console.error("Error processing record:", error);
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }

  return batchItemFailures;
};

export const handler = middy<SQSEvent, IBatchItemFailure[]>(sqsProcessor);
