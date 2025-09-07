import middy from "@middy/core";
import { type SQSEvent, type SQSBatchResponse } from "aws-lambda";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";
import { CardErrorsService } from "../services/card-errors/card-errors.service.js";

interface IBatchItemFailure {
  itemIdentifier: string;
}

const dlqProcessor = async (event: SQSEvent): Promise<SQSBatchResponse> => {
  const batchItemFailures: IBatchItemFailure[] = [];
  const cardErrorServices = new CardErrorsService(new DynamoDBService());

  for (const record of event.Records) {
    const messageId = record.messageId;
    const payload = record.body;
    await cardErrorServices.saveDqlEventToDB(messageId, payload);
  }

  return {
    batchItemFailures: batchItemFailures,
  };
};

export const handler = middy<SQSEvent, SQSBatchResponse>(dlqProcessor);
