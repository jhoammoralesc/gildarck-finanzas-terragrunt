const GROUP_SCOPES_MAPPING = {
  "rtp-services": [
    "rtp.status.write",
    "rtp.recurring.status.write",
    "rtp.chargebacks.status.write",
  ],
  "rtp-clients": [
    "rtp.chargebacks.write",
    "rtp.services.write",
    "rtp.services.read",
    "rtp.rtps.write",
    "rtp.rtps.read",
    "rtp.recurring.write",
    "rtp.recurring.read",
    "rtp.notifications.write",
    "rtp.notifications.read",
  ],
  ai: ["ai.fact", "ai.ret"],
  "gildarck-clients": [
    "gildarck.debtdocuments.write",
    "gildarck.debtdocuments.read",
    "gildarck.externallogin.write",
  ],
  "gildarck-clients-renditions": ["gildarck.renditions.read"],
  "gildarck-clients-renditions-instrument": [
    "gildarck.renditionsintrument.read",
  ],
};

exports.handler = async (event, context) => {
  const userGroups = event.request.groupConfiguration.groupsToOverride;
  const requestedScopes =
    event.request.userAttributes["custom:requested_scopes"]?.split(" ") || [];

  // Get all allowed scopes for user's groups
  const allowedScopes = userGroups.reduce((scopes, group) => {
    if (GROUP_SCOPES_MAPPING[group]) {
      scopes.push(...GROUP_SCOPES_MAPPING[group]);
    }
    return scopes;
  }, []);

  // Filter requested scopes to only include allowed ones
  const validScopes = requestedScopes.filter((scope) =>
    allowedScopes.includes(scope)
  );

  event.response.claimsAndScopeOverrideDetails = {
    accessTokenGeneration: {
      scopesToAdd: validScopes,
      claimsToAddOrOverride: {
        commercial_id:
          event.request.userAttributes["custom:commercial_id"] ?? "",
      },
    },
  };

  console.log(`User groups: ${userGroups.join(", ")}`);
  console.log(`Requested scopes: ${requestedScopes.join(", ")}`);
  console.log(`Granted scopes: ${validScopes.join(", ")}`);

  context.done(null, event);
};
