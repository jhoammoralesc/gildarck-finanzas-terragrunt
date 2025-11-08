import { type ClientSchema, a, defineData } from "@aws-amplify/backend";

const schema = a.schema({
  Transaction: a
    .model({
      user_id: a.string().required(),
      transaction_id: a.string().required(),
      chat_id: a.integer(),
      username: a.string(),
      message_id: a.integer(),
      amount: a.float().required(),
      type: a.enum(["income", "expense"]),
      description: a.string(),
      category: a.string(),
      is_leisure: a.boolean(),
      currency: a.string().default("COP"),
      confidence: a.float(),
      processing_method: a.string(),
      reasoning: a.string(),
      original_text: a.string(),
      date_only: a.string(),
      month_year: a.string(),
    })
    .authorization((allow) => [allow.publicApiKey()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: "apiKey",
    apiKeyAuthorizationMode: {
      expiresInDays: 30,
    },
  },
});
