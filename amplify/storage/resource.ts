import { defineStorage } from "@aws-amplify/backend";

export const storage = defineStorage({
  name: "finanzasStorage",
  access: (allow) => ({
    "photos/*": [
      allow.authenticated.to(["read", "write", "delete"]),
      allow.guest.to(["read", "write"]),
    ],
    "receipts/*": [
      allow.authenticated.to(["read", "write", "delete"]),
      allow.guest.to(["read", "write"]),
    ],
  }),
});
