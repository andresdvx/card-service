import { S3Client, PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";
import { Readable } from "stream";

export class S3Service {
  private client: S3Client;
  private bucket: string;
  private readonly region: string = "us-west-1";

  constructor(bucket: string) {
    this.client = new S3Client({ region: this.region });
    this.bucket = bucket;
  }

  async uploadTxtFile(key: string, content: string): Promise<any> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: content,
      ContentType: "text/plain",
    });
    return await this.client.send(command);
  }

  async getTxtFile(key: string): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });
    const response = await this.client.send(command);
    if (!response.Body) throw new Error("No file body returned from S3");
    const stream = response.Body as Readable;
    const chunks: Buffer[] = [];
    for await (const chunk of stream) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    return Buffer.concat(chunks).toString("utf-8");
  }
}
