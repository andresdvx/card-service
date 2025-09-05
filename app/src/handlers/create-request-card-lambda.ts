import middy from "@middy/core";
import { type SQSEvent } from "aws-lambda";

interface IBatchItemFailure {
  itemIdentifier: string;
}

const sqsProcessor = (event: SQSEvent) => {
    const batchItemFailures: IBatchItemFailure[] = [];

    for (const record of event.Records) {
        try{
            const {userId, request} = JSON.parse(record.body);
            switch(request){
                case "CREDIT":
                   console.log("Credit Event Processed for user:", userId);
                    break;
                case "DEBIT":
                   console.log("Debit Event Processed for user:", userId);
                    break;
                default:
                    throw new Error("Message Type Unrecognized");
            }
        }catch(error){
            console.error("Error processing record:", error);
            batchItemFailures.push({ itemIdentifier: record.messageId });
        }
    }

    return batchItemFailures;
};

export const handler = middy<SQSEvent, IBatchItemFailure[]>(sqsProcessor);