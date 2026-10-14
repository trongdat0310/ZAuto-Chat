import { ThreadType } from "zca-js";
import { connectUserZalo } from "../zalo/user-zalo-manager.js";
import { getUserGroups } from "../zalo/user-groups.js";
import { findUserConversationMessage } from "./conversation-store.js";
import { createChatAcceptService } from "./chat-accept-core.js";

export const acceptUserChatMessage = createChatAcceptService({
  findMessage: findUserConversationMessage,
  getGroups: getUserGroups,
  connect: connectUserZalo,
  groupType: ThreadType.Group,
});
