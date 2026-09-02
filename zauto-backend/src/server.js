import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import multer from "multer";
import sharp from "sharp";

import {
  connectZalo,
  getZaloStatus,
} from "./zalo/connector.js";

import {
  getGroups,
  setGroupEnabled,
} from "./zalo/groups.js";

import {
  startZaloListener,
} from "./zalo/listener.js";

import {
  getFilterSettings,
  saveFilterSettings,
} from "./filters/filter-engine.js";

import {
  getMessages,
  getMessageById,
} from "./messages/message-store.js";

import {
  acceptMessage,
  ignoreMessage,
} from "./messages/message-service.js";

import http from "node:http";

import {
  initWebSocket,
} from "./realtime/ws-server.js";

import {
  registerDevice,
} from "./devices/device-store.js";

import {
  initFirebaseAdmin,
} from "./push/firebase-admin.js";

import {
  registerUser,
  loginUser,
  toPublicUser,
} from "./auth/auth-service.js";

import {
  requireAuth,
} from "./auth/auth-middleware.js";

import {
  startZaloLink,
  getZaloLinkStatus,
  cancelZaloLink,
} from "./zalo/link-manager.js";

import {
  connectUserZalo,
  getUserZaloStatus,
} from "./zalo/user-zalo-manager.js";

import {
  getUserGroups,
} from "./zalo/user-groups.js";

import {
  revokeToken,
} from "./auth/revoked-token-store.js";

import {
  setUserGroupEnabled,
} from "./zalo/user-group-settings.js";

import {
  getUserFilterSettings,
  saveUserFilterSettings,
} from "./filters/user-filter-engine.js";

import {
  getUserMessages,
  getUserMessageById,
} from "./messages/user-message-store.js";

import {
  acceptUserMessage,
  ignoreUserMessage,
} from "./messages/user-message-service.js";

import {
  registerUserDevice,
  unregisterUserDevice,
  getPublicUserDevices,
} from "./devices/user-device-store.js";

import {
  sendUserTestPush,
} from "./push/user-push-service.js";

import {
  startUserWorker,
  getUserWorkerStatus,
  startAllUserWorkers,
  stopUserWorker,
  sendUserConversationPhoto,
  sendUserConversationPhotos,
} from "./workers/user-worker-manager.js";

import {
  startNetworkWatchdog,
  getNetworkWatchdogStatus,
} from "./watchdog/network-watchdog.js";

import {
  findUserById,
  updateUser,
} from "./users/user-store.js";

import {
  deleteUserZaloSession,
} from "./zalo/user-zalo-store.js";

import {
  updateAccountName,
  changeAccountPassword,
  deleteAccount,
} from "./account/account-service.js";

import {
  getUserConversationList,
  getUserConversationMessages,
  getUserConversationMessagesPage,
  findUserConversationMessage,
  syncConversationGroups,
  getUserConversationMessageContext,
  markUserConversationRead,
  setUserConversationPinned,
} from "./conversations/conversation-store.js";

import {
  getUserMessageSettings,
  updateUserMessageSettings,
} from "./settings/user-message-settings-store.js";

import {
  broadcastUserEvent,
} from "./realtime/ws-server.js";

import {
  sendUserConversationMessage,
} from "./conversations/conversation-send-service.js";

import {
  undoUserConversationMessage,
} from "./conversations/conversation-undo-service.js";

import {
  deleteUserConversationMessage,
} from "./conversations/conversation-delete-service.js";

dotenv.config();

// ========================================
// CONVERSATION PHOTO UPLOAD
//
// DUNG MEMORY STORAGE.
//
// File chi ton tai trong RAM trong luc gui,
// khong luu rac vao o cung backend.
// ========================================

const conversationPhotoUpload =
  multer({

    storage:
      multer.memoryStorage(),


    limits: {

      // Moi request chi gui 1 anh.
      files:
        10,


      // Gioi han app cua chung ta:
      // 15 MB / anh.
      fileSize:
        15 *
        1024 *
        1024,
    },
  });

const app = express();

const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());


// ========================================
// HEALTH CHECK
// ========================================

app.get("/health", (req, res) => {
  res.json({
    ok: true,
    service: "zauto-backend",
    time: new Date().toISOString(),
  });
});


// ========================================
// ZALO STATUS
// ========================================

app.get("/api/zalo/status", (req, res) => {
  res.json(getZaloStatus());
});

// ========================================
// GROUPS
// ========================================

app.get("/api/groups", async (req, res) => {
  try {
    const groups = await getGroups();

    res.json({
      success: true,
      count: groups.length,
      groups,
    });
  } catch (error) {
    console.error(
      "[GROUPS] GET ERROR:",
      error
    );

    res.status(500).json({
      success: false,
      error: error?.message ?? String(error),
    });
  }
});


// ========================================
// BAT / TAT GROUP
// ========================================

app.post(
  "/api/groups/:groupId/toggle",
  (req, res) => {
    try {
      const { groupId } = req.params;

      const { enabled } = req.body;

      if (typeof enabled !== "boolean") {
        return res.status(400).json({
          success: false,
          error:
            "enabled phai la true hoac false",
        });
      }

      const result = setGroupEnabled(
        groupId,
        enabled
      );

      res.json({
        success: true,
        ...result,
      });
    } catch (error) {
      console.error(
        "[GROUPS] TOGGLE ERROR:",
        error
      );

      res.status(500).json({
        success: false,
        error:
          error?.message ?? String(error),
      });
    }
  }
);

// ========================================
// FILTER SETTINGS
// ========================================

app.get("/api/filters", (req, res) => {
  res.json({
    success: true,
    filters: getFilterSettings(),
  });
});

app.put("/api/filters", (req, res) => {
  try {
    const {
      includeKeywords,
      excludeKeywords,
      enabled,
    } = req.body;

    if (
      includeKeywords !== undefined &&
      !Array.isArray(includeKeywords)
    ) {
      return res.status(400).json({
        success: false,
        error: "includeKeywords phai la array",
      });
    }

    if (
      excludeKeywords !== undefined &&
      !Array.isArray(excludeKeywords)
    ) {
      return res.status(400).json({
        success: false,
        error: "excludeKeywords phai la array",
      });
    }

    const filters = saveFilterSettings({
      ...(includeKeywords !== undefined
        ? { includeKeywords }
        : {}),
      ...(excludeKeywords !== undefined
        ? { excludeKeywords }
        : {}),
      ...(enabled !== undefined
        ? { enabled: Boolean(enabled) }
        : {}),
    });

    res.json({
      success: true,
      filters,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error?.message ?? String(error),
    });
  }
});

// ========================================
// MESSAGES
// ========================================

app.get("/api/messages", (req, res) => {
  const requestedLimit =
    Number(req.query.limit) || 100;

  const messages =
    getMessages(requestedLimit);

  res.json({
    success: true,
    count: messages.length,
    messages,
  });
});

app.get(
  "/api/messages/:id",
  (req, res) => {
    const message =
      getMessageById(req.params.id);

    if (!message) {
      return res.status(404).json({
        success: false,
        error: "Khong tim thay message",
      });
    }

    res.json({
      success: true,
      message,
    });
  }
);

// ========================================
// ACCEPT / NHAN CUOC
// ========================================

app.post(
  "/api/messages/:id/accept",
  async (req, res) => {

    try {
      const replyText =
        req.body?.replyText ?? "Nhận";


      const result =
        await acceptMessage(
          req.params.id,
          replyText
        );


      res.json({
        success: true,

        alreadyAccepted:
          result.alreadyAccepted,

        message:
          result.message,
      });

    } catch (error) {

      console.error(
        "[ACCEPT API] ERROR:",
        error
      );


      if (
        error.code ===
        "MESSAGE_NOT_FOUND"
      ) {
        return res
          .status(404)
          .json({
            success: false,
            error:
              "Khong tim thay message",
          });
      }


      res
        .status(500)
        .json({
          success: false,
          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// IGNORE / BO QUA CUOC
// ========================================

app.post(
  "/api/messages/:id/ignore",
  async (req, res) => {

    try {
      const result =
        await ignoreMessage(
          req.params.id
        );

      res.json({
        success: true,

        alreadyIgnored:
          result.alreadyIgnored,

        message:
          result.message,
      });

    } catch (error) {

      if (
        error.code ===
        "MESSAGE_NOT_FOUND"
      ) {
        return res
          .status(404)
          .json({
            success: false,
            error:
              "Khong tim thay message",
          });
      }


      if (
        error.code ===
        "MESSAGE_ALREADY_ACCEPTED"
      ) {
        return res
          .status(409)
          .json({
            success: false,
            error:
              "Cuoc nay da duoc nhan",
          });
      }


      res
        .status(500)
        .json({
          success: false,
          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// DEVICE REGISTER
// ========================================

app.post(
  "/api/devices/register",
  (req, res) => {

    try {
      const {
        token,
        platform,
      } = req.body;


      if (
        typeof token !== "string" ||
        token.trim().length < 10
      ) {
        return res
          .status(400)
          .json({
            success: false,
            error:
              "FCM token khong hop le",
          });
      }


      const device =
        registerDevice({
          token:
            token.trim(),

          platform:
            platform ??
            "unknown",
        });


      res.json({
        success: true,
        device: {
          id:
            device.id,

          platform:
            device.platform,

          enabled:
            device.enabled,
        },
      });

    } catch (error) {

      res.status(500).json({
        success: false,

        error:
          error?.message ??
          String(error),
      });
    }
  }
);

// ========================================
// AUTH REGISTER
// ========================================

app.post(
  "/api/auth/register",
  async (req, res) => {

    try {
      const {
        name,
        phone,
        password,
      } = req.body;


      const result =
        await registerUser({
          name,
          phone,
          password,
        });


      res.status(201).json({
        success:
          true,

        ...result,
      });

    } catch (error) {

      const status =
        error.code ===
        "PHONE_EXISTS"
          ? 409
          : 400;


      res
        .status(status)
        .json({
          success:
            false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);


// ========================================
// AUTH LOGIN
// ========================================

app.post(
  "/api/auth/login",
  async (req, res) => {

    try {
      const {
        phone,
        password,
      } = req.body;


      const result =
        await loginUser({
          phone,
          password,
        });


      res.json({
        success:
          true,

        ...result,
      });

    } catch (error) {

      res
        .status(401)
        .json({
          success:
            false,

          error:
            error?.message ??
            "Dang nhap that bai.",
        });
    }
  }
);


// ========================================
// CURRENT USER
// ========================================

app.get(
  "/api/me",

  requireAuth,

  (req, res) => {

    res.json({
      success:
        true,

      user:
        toPublicUser(
          req.user
        ),
    });
  }
);

// ========================================
// ZALO LINK START
// ========================================

app.post(
  "/api/zalo/link/start",

  requireAuth,

  (req, res) => {
    try {
      const result =
        startZaloLink(
          req.user
        );

      res.status(202).json({
        success: true,
        link: result,
      });

    } catch (error) {

      res.status(500).json({
        success: false,

        error:
          error?.message ??
          String(error),
      });
    }
  }
);


// ========================================
// ZALO LINK STATUS
// ========================================

app.get(
  "/api/zalo/link/status",

  requireAuth,

  (req, res) => {

    const link =
      getZaloLinkStatus(
        req.user.id
      );


    res.json({
      success: true,
      link,
    });
  }
);


// ========================================
// ZALO LINK CANCEL
// ========================================

app.post(
  "/api/zalo/link/cancel",

  requireAuth,

  (req, res) => {

    const link =
      cancelZaloLink(
        req.user.id
      );


    res.json({
      success: true,
      link,
    });
  }
);

// ========================================
// USER ZALO STATUS
// ========================================

app.get(
  "/api/me/zalo/status",

  requireAuth,

  async (req, res) => {

    try {

      await connectUserZalo(
        req.user.id
      );


      res.json({
        success: true,

        zalo:
          getUserZaloStatus(
            req.user.id
          ),
      });

    } catch (error) {

      if (
        error.code ===
        "ZALO_NOT_LINKED"
      ) {
        return res
          .status(409)
          .json({
            success: false,
            error:
              "Tai khoan chua lien ket Zalo.",
          });
      }


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// CURRENT USER GROUPS
// ========================================

app.get(
  "/api/me/groups",

  requireAuth,

  async (req, res) => {

    try {

      const groups =
        await getUserGroups(
          req.user.id
        );


      res.json({
        success: true,

        count:
          groups.length,

        groups,
      });

    } catch (error) {

      console.error(
        "[ME GROUPS] ERROR:",
        error
      );


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// CURRENT USER GROUP TOGGLE
// ========================================

app.post(
  "/api/me/groups/:groupId/toggle",

  requireAuth,

  async (req, res) => {

    try {
      const userId =
        req.user.id;

      const groupId =
        String(
          req.params.groupId
        );

      const {
        enabled,
      } = req.body;


      if (
        typeof enabled !==
        "boolean"
      ) {
        return res
          .status(400)
          .json({
            success: false,

            error:
              "enabled phai la true hoac false.",
          });
      }


      // ========================================
      // KIEM TRA GROUP CO THUOC
      // ZALO CUA USER NAY KHONG
      // ========================================

      const groups =
        await getUserGroups(
          userId
        );


      const group =
        groups.find(
          item =>
            String(
              item.groupId
            ) === groupId
        );


      if (!group) {
        return res
          .status(404)
          .json({
            success: false,

            error:
              "Khong tim thay group trong tai khoan Zalo nay.",
          });
      }


      const result =
        setUserGroupEnabled(
          userId,
          groupId,
          enabled
        );


      res.json({
        success: true,

        group: {
          ...group,
          enabled:
            result.enabled,
        },
      });

    } catch (error) {

      console.error(
        "[ME GROUP TOGGLE] ERROR:",
        error
      );


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// AUTH LOGOUT
// ========================================

// ========================================
// CURRENT USER FILTERS
// ========================================

app.get(
  "/api/me/filters",

  requireAuth,

  (req, res) => {

    const filters =
      getUserFilterSettings(
        req.user.id
      );


    res.json({
      success: true,

      filters,
    });
  }
);

// ========================================
// UPDATE CURRENT USER FILTERS
// ========================================

app.put(
  "/api/me/filters",

  requireAuth,

  (req, res) => {

    try {
      const {
        enabled,
        includeKeywords,
        excludeKeywords,
      } = req.body;


      if (
        enabled !== undefined &&
        typeof enabled !==
          "boolean"
      ) {
        return res
          .status(400)
          .json({
            success: false,

            error:
              "enabled phai la boolean.",
          });
      }


      if (
        includeKeywords !==
          undefined &&
        !Array.isArray(
          includeKeywords
        )
      ) {
        return res
          .status(400)
          .json({
            success: false,

            error:
              "includeKeywords phai la array.",
          });
      }


      if (
        excludeKeywords !==
          undefined &&
        !Array.isArray(
          excludeKeywords
        )
      ) {
        return res
          .status(400)
          .json({
            success: false,

            error:
              "excludeKeywords phai la array.",
          });
      }


      const filters =
        saveUserFilterSettings(
          req.user.id,
          {
            ...(enabled !==
            undefined
              ? {
                  enabled,
                }
              : {}),

            ...(includeKeywords !==
            undefined
              ? {
                  includeKeywords,
                }
              : {}),

            ...(excludeKeywords !==
            undefined
              ? {
                  excludeKeywords,
                }
              : {}),
          }
        );


      res.json({
        success: true,

        filters,
      });

    } catch (error) {

      console.error(
        "[ME FILTERS] ERROR:",
        error
      );


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

app.post(
  "/api/auth/logout",

  requireAuth,

  (req, res) => {

    revokeToken({
      jti:
        req.authPayload.jti,

      exp:
        req.authPayload.exp,
    });


    res.json({
      success: true,
      message:
        "Dang xuat thanh cong.",
    });
  }
);

// ========================================
// CURRENT USER MESSAGES
// ========================================

app.get(
  "/api/me/messages",

  requireAuth,

  (req, res) => {

    const requestedLimit =
      Number(
        req.query.limit
      ) || 100;


    const messages =
      getUserMessages(
        req.user.id,
        requestedLimit
      );


    res.json({
      success: true,

      count:
        messages.length,

      messages,
    });
  }
);


// ========================================
// CURRENT USER MESSAGE DETAIL
// ========================================

app.get(
  "/api/me/messages/:id",

  requireAuth,

  (req, res) => {

    const message =
      getUserMessageById(
        req.user.id,
        req.params.id
      );


    if (!message) {
      return res
        .status(404)
        .json({
          success: false,

          error:
            "Khong tim thay cuoc.",
        });
    }


    res.json({
      success: true,
      message,
    });
  }
);


// ========================================
// ACCEPT CURRENT USER MESSAGE
// ========================================

app.post(
  "/api/me/messages/:id/accept",

  requireAuth,

  async (req, res) => {

    try {

      const userId =
        req.user.id;


      const replyText =
        req.body?.replyText ??
        "Nhận";


      // ========================================
      // NHAN CUOC
      // ========================================

      const result =
        await acceptUserMessage(
          userId,
          req.params.id,
          replyText
        );


      // ========================================
      // PHAT REALTIME SAU KHI NHAN THANH CONG
      // ========================================

      const acceptedMessageId =
        String(
          req.params.id
        );


      broadcastUserEvent(
        userId,
        "trip_accepted",
        {
          messageId:
            acceptedMessageId,
        }
      );


      console.log(
        "[TRIP ACCEPTED REALTIME]",
        userId,
        acceptedMessageId
      );


      return res.json({
        success:
          true,

        alreadyAccepted:
          result.alreadyAccepted,

        message:
          result.message,
      });

    } catch (error) {

      // ========================================
      // KHONG PHAT trip_accepted O DAY
      // VI ACCEPT DA THAT BAI
      // ========================================

      if (
        error.code ===
        "MESSAGE_NOT_FOUND"
      ) {

        return res
          .status(404)
          .json({
            success:
              false,

            error:
              "Khong tim thay cuoc.",
          });
      }


      if (
        error.code ===
        "MESSAGE_ALREADY_IGNORED"
      ) {

        return res
          .status(409)
          .json({
            success:
              false,

            error:
              "Cuoc nay da bi bo qua.",
          });
      }


      console.error(
        "[ME ACCEPT] ERROR:",
        error
      );


      return res
        .status(500)
        .json({
          success:
            false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);


// ========================================
// IGNORE CURRENT USER MESSAGE
// ========================================

app.post(
  "/api/me/messages/:id/ignore",

  requireAuth,

  async (req, res) => {

    try {

      const result =
        await ignoreUserMessage(
          req.user.id,
          req.params.id
        );


      res.json({
        success: true,

        alreadyIgnored:
          result.alreadyIgnored,

        message:
          result.message,
      });

    } catch (error) {

      if (
        error.code ===
        "MESSAGE_NOT_FOUND"
      ) {
        return res
          .status(404)
          .json({
            success: false,

            error:
              "Khong tim thay cuoc.",
          });
      }


      if (
        error.code ===
        "MESSAGE_ALREADY_ACCEPTED"
      ) {
        return res
          .status(409)
          .json({
            success: false,

            error:
              "Cuoc nay da duoc nhan.",
          });
      }


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// REGISTER CURRENT USER DEVICE
// ========================================

app.post(
  "/api/me/devices/register",

  requireAuth,

  (req, res) => {

    try {
      const {
        token,
        platform,
      } = req.body;


      if (
        typeof token !==
          "string" ||
        token.trim().length < 10
      ) {
        return res
          .status(400)
          .json({
            success: false,

            error:
              "FCM token khong hop le.",
          });
      }


      const device =
        registerUserDevice(
          req.user.id,
          {
            token:
              token.trim(),

            platform:
              platform ??
              "unknown",
          }
        );


      res.json({
        success: true,

        device: {
          id:
            device.id,

          platform:
            device.platform,

          enabled:
            device.enabled,
        },
      });

    } catch (error) {

      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);


// ========================================
// UNREGISTER CURRENT USER DEVICE
// ========================================

app.post(
  "/api/me/devices/unregister",

  requireAuth,

  (req, res) => {

    const {
      token,
    } = req.body;


    if (
      typeof token !==
        "string" ||
      token.isEmpty
    ) {
      return res
        .status(400)
        .json({
          success: false,

          error:
            "FCM token khong hop le.",
        });
    }


    const removed =
      unregisterUserDevice(
        req.user.id,
        token
      );


    res.json({
      success: true,
      removed,
    });
  }
);


// ========================================
// LIST CURRENT USER DEVICES
// ========================================

app.get(
  "/api/me/devices",

  requireAuth,

  (req, res) => {

    const devices =
      getPublicUserDevices(
        req.user.id
      );


    res.json({
      success: true,

      count:
        devices.length,

      devices,
    });
  }
);


// ========================================
// TEST PUSH CURRENT USER
// ========================================

app.post(
  "/api/me/devices/test-push",

  requireAuth,

  async (req, res) => {

    try {

      const result =
        await sendUserTestPush(
          req.user.id
        );


      res.json({
        success: true,
        ...result,
      });

    } catch (error) {

      console.error(
        "[ME TEST PUSH] ERROR:",
        error
      );


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// CURRENT USER WORKER START
// ========================================

app.post(
  "/api/me/worker/start",

  requireAuth,

  async (req, res) => {

    try {

      const worker =
        await startUserWorker(
          req.user.id
        );


      res.json({
        success: true,
        worker,
      });

    } catch (error) {

      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);


// ========================================
// CURRENT USER WORKER STATUS
// ========================================

app.get(
  "/api/me/worker/status",

  requireAuth,

  (req, res) => {

    res.json({
      success: true,

      worker:
        getUserWorkerStatus(
          req.user.id
        ),
    });
  }
);

// ========================================
// CURRENT USER PROFILE
// ========================================

app.get(
  "/api/me/profile",

  requireAuth,

  (req, res) => {

    const user =
      findUserById(
        req.user.id
      );


    if (!user) {

      return res
        .status(404)
        .json({
          success: false,

          error:
            "Tai khoan khong ton tai.",
        });
    }


    const worker =
      getUserWorkerStatus(
        user.id
      );


    const network =
      getNetworkWatchdogStatus();


    res.json({
      success: true,

      user: {
        id:
          user.id,

        name:
          user.name,

        phone:
          user.phone,

        membership:
          user.membership,

        zaloLinked:
          user.zaloLinked ===
          true,

        zaloUserId:
          user.zaloUserId ??
          null,

        createdAt:
          user.createdAt,
      },

      worker,

      network,
    });
  }
);

// ========================================
// UNLINK CURRENT USER ZALO
// ========================================

app.post(
  "/api/me/zalo/unlink",

  requireAuth,

  async (req, res) => {

    try {

      const userId =
        req.user.id;


      console.log(
        "[ZALO UNLINK] START:",
        userId
      );


      // ========================================
      // 1. STOP REALTIME WORKER
      // ========================================

      await stopUserWorker(
        userId
      );


      // ========================================
      // 2. DELETE ENCRYPTED ZALO SESSION
      // ========================================

      await Promise.resolve(
        deleteUserZaloSession(
          userId
        )
      );


      // ========================================
      // 3. UPDATE APP USER
      // ========================================

      const updatedUser =
        updateUser(
          userId,
          {
            zaloLinked:
              false,

            zaloUserId:
              null,
          }
        );


      console.log(
        "[ZALO UNLINK] SUCCESS:",
        userId
      );


      res.json({
        success: true,

        message:
          "Da ngat lien ket Zalo.",

        user: {
          id:
            updatedUser.id,

          name:
            updatedUser.name,

          phone:
            updatedUser.phone,

          membership:
            updatedUser.membership,

          zaloLinked:
            false,

          zaloUserId:
            null,
        },
      });

    } catch (error) {

      console.error(
        "[ZALO UNLINK] ERROR:",
        error
      );


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// UPDATE PROFILE
// ========================================

app.patch(
  "/api/me/profile",

  requireAuth,

  (req, res) => {

    try {

      const user =
        updateAccountName(
          req.user.id,
          req.body?.name
        );


      res.json({
        success: true,
        user,
      });

    } catch (error) {

      const status =
        error.code ===
          "INVALID_NAME"
          ? 400
          : error.code ===
              "USER_NOT_FOUND"
            ? 404
            : 500;


      res
        .status(status)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// CHANGE PASSWORD
// ========================================

app.post(
  "/api/me/change-password",

  requireAuth,

  async (req, res) => {

    try {

      await changeAccountPassword(
        req.user.id,
        req.body?.currentPassword,
        req.body?.newPassword
      );


      res.json({
        success: true,

        message:
          "Doi mat khau thanh cong.",
      });

    } catch (error) {

      const clientErrors =
        new Set([
          "CURRENT_PASSWORD_REQUIRED",
          "WEAK_PASSWORD",
          "WRONG_PASSWORD",
          "SAME_PASSWORD",
        ]);


      res
        .status(
          clientErrors.has(
            error.code
          )
            ? 400
            : 500
        )
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// DELETE ACCOUNT
// ========================================

app.delete(
  "/api/me/account",

  requireAuth,

  async (req, res) => {

    try {

      await deleteAccount(
        req.user.id,
        req.body?.password
      );


      res.json({
        success: true,

        message:
          "Tai khoan da duoc xoa.",
      });

    } catch (error) {

      const status =
        error.code ===
          "WRONG_PASSWORD" ||
        error.code ===
          "PASSWORD_REQUIRED"
          ? 400
          : error.code ===
              "USER_NOT_FOUND"
            ? 404
            : 500;


      res
        .status(status)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// GET ALL CONVERSATIONS
// ========================================

app.get(
  "/api/me/conversations",

  requireAuth,

  (req, res) => {

    try {

      const conversations =
        getUserConversationList(
          req.user.id
        );


      res.json({
        success: true,

        conversations,

        total:
          conversations.length,
      });

    } catch (error) {

      console.error(
        "[CONVERSATIONS] LIST ERROR:",
        req.user.id,
        error
      );


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// GET CONVERSATION MESSAGES
// CURSOR PAGINATION
// ========================================

app.get(
  "/api/me/conversations/:groupId/messages",

  requireAuth,

  (req, res) => {

    try {

      const groupId =
        String(
          req.params.groupId
        );


      const requestedLimit =
        Number(
          req.query.limit
        );


      const limit =
        Number.isFinite(
          requestedLimit
        )
          ? requestedLimit
          : 50;


      const beforeId =
        req.query.beforeId != null
          ? String(
              req.query.beforeId
            )
          : null;


      const afterId =
        req.query.afterId != null
          ? String(
              req.query.afterId
            )
          : null;


      if (
        beforeId &&
        afterId
      ) {

        return res
          .status(400)
          .json({
            success:
              false,

            error:
              "Chi duoc dung beforeId hoac afterId.",
          });
      }


      const page =
        getUserConversationMessagesPage(
          req.user.id,
          groupId,
          {
            limit,
            beforeId,
            afterId,
          }
        );


      return res.json({
        success:
          true,

        groupId,

        messages:
          page.messages,

        total:
          page.messages.length,

        hasBefore:
          page.hasBefore,

        hasAfter:
          page.hasAfter,

        anchorFound:
          page.anchorFound,
      });

    } catch (error) {

      console.error(
        "[CONVERSATIONS] MESSAGES ERROR:",
        req.user.id,
        req.params.groupId,
        error
      );


      return res
        .status(500)
        .json({
          success:
            false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// MARK CONVERSATION AS READ
// ========================================

app.post(
  "/api/me/conversations/:groupId/read",

  requireAuth,

  (
    req,
    res
  ) => {

    try {

      const groupId =
        String(
          req.params.groupId ??
          ""
        ).trim();


      if (!groupId) {

        return res
          .status(400)
          .json({
            success:
              false,

            error:
              "Group ID khong hop le.",
          });
      }


      const conversation =
        markUserConversationRead(
          req.user.id,
          groupId
        );


      if (!conversation) {

        return res
          .status(404)
          .json({
            success:
              false,

            error:
              "Khong tim thay hoi thoai.",
          });
      }


      // ========================================
      // REALTIME
      //
      // MessagesPage sau nay se bat event nay
      // de xoa unread badge ngay lap tuc.
      // ========================================

      broadcastUserEvent(
        req.user.id,
        "conversation_read",
        {
          groupId,

          unreadCount:
            0,

          lastReadAt:
            conversation
              .lastReadAt,
        }
      );


      return res.json({

        success:
          true,


        conversation,
      });

    } catch (error) {

      console.error(
        "[CONVERSATION] MARK READ ERROR:",
        req.user.id,
        req.params.groupId,
        error
      );


      return res
        .status(500)
        .json({
          success:
            false,

          error:
            error?.message ??
            String(
              error
            ),
        });
    }
  }
);

// ========================================
// FIND EXACT SOURCE MESSAGE
// ========================================

app.get(
  "/api/me/conversations/:groupId/messages/target",

  requireAuth,

  (req, res) => {

    try {

      const groupId =
        String(
          req.params.groupId
        );


      const msgId =
        req.query.msgId != null
          ? String(
              req.query.msgId
            )
          : null;


      const cliMsgId =
        req.query.cliMsgId != null
          ? String(
              req.query.cliMsgId
            )
          : null;


      if (
        !msgId &&
        !cliMsgId
      ) {

        return res
          .status(400)
          .json({
            success: false,

            error:
              "Can msgId hoac cliMsgId.",
          });
      }


      const message =
        findUserConversationMessage(
          req.user.id,
          groupId,
          {
            msgId,
            cliMsgId,
          }
        );


      // ========================================
      // KHONG TON TAI
      // ========================================

      if (!message) {

        return res
          .status(404)
          .json({
            success: false,

            found: false,

            reason:
              "not_found",

            error:
              "Khong tim thay tin nhan.",
          });
      }


      // ========================================
      // DA THU HOI
      // ========================================

      if (
        message.status ===
        "recalled"
      ) {

        return res.json({
          success: true,

          found: false,

          reason:
            "recalled",

          message:
            null,

          notice:
            "Tin nhan da duoc thu hoi.",
        });
      }


      // ========================================
      // DA XOA PHIA TAI KHOAN
      // ========================================

      if (
        message.status ===
        "deleted_local"
      ) {

        return res.json({
          success: true,

          found: false,

          reason:
            "deleted_local",

          message:
            null,

          notice:
            "Tin nhan da bi xoa.",
        });
      }


      // ========================================
      // FOUND
      // ========================================

      res.json({
        success: true,

        found: true,

        reason:
          null,

        message,
      });

    } catch (error) {

      console.error(
        "[CONVERSATIONS] TARGET ERROR:",
        req.user.id,
        req.params.groupId,
        error
      );


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// SYNC CONVERSATION GROUPS
// ========================================

app.post(
  "/api/me/conversations/sync",

  requireAuth,

  async (req, res) => {

    try {

      const groups =
        await getUserGroups(
          req.user.id
        );


      const conversations =
        syncConversationGroups(
          req.user.id,
          groups
        );


      console.log(
        "[CONVERSATIONS] MANUAL SYNC:",
        req.user.id,
        conversations.length
      );


      res.json({
        success: true,

        totalGroups:
          groups.length,

        totalConversations:
          conversations.length,

        conversations,
      });

    } catch (error) {

      console.error(
        "[CONVERSATIONS] SYNC ERROR:",
        req.user.id,
        error
      );


      res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// GET CONTEXT AROUND SOURCE MESSAGE
// ========================================

app.get(
  "/api/me/conversations/:groupId/messages/context",

  requireAuth,

  (req, res) => {

    try {

      const groupId =
        String(
          req.params.groupId
        );


      const msgId =
        req.query.msgId != null
          ? String(
              req.query.msgId
            )
          : null;


      const cliMsgId =
        req.query.cliMsgId != null
          ? String(
              req.query.cliMsgId
            )
          : null;


      if (
        !msgId &&
        !cliMsgId
      ) {

        return res
          .status(400)
          .json({
            success: false,
            error:
              "Can msgId hoac cliMsgId.",
          });
      }


      const result =
        getUserConversationMessageContext(
          req.user.id,
          groupId,
          {
            msgId,
            cliMsgId,

            before:
              req.query.before,

            after:
              req.query.after,
          }
        );


      return res.json({
        success: true,
        ...result,
      });

    } catch (error) {

      console.error(
        "[CONVERSATION CONTEXT] ERROR:",
        req.user.id,
        req.params.groupId,
        error
      );


      return res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// GET MESSAGE SETTINGS
// ========================================

app.get(
  "/api/me/message-settings",
  requireAuth,
  (req, res) => {

    try {

      const settings =
        getUserMessageSettings(
          req.user.id
        );


      return res.json({
        success: true,
        settings,
      });

    } catch (error) {

      console.error(
        "[MESSAGE SETTINGS] GET ERROR:",
        req.user.id,
        error
      );


      return res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);


// ========================================
// UPDATE MESSAGE SETTINGS
// ========================================

app.patch(
  "/api/me/message-settings",
  requireAuth,
  (req, res) => {

    try {

      const settings =
        updateUserMessageSettings(
          req.user.id,
          req.body ?? {}
        );


      return res.json({
        success: true,
        settings,
      });

    } catch (error) {

      console.error(
        "[MESSAGE SETTINGS] UPDATE ERROR:",
        req.user.id,
        error
      );


      return res
        .status(500)
        .json({
          success: false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// SEND / REPLY MESSAGE TO ZALO GROUP
// ========================================

app.post(
  "/api/me/conversations/:groupId/messages/send",

  requireAuth,

  async (req, res) => {

    try {

      const groupId =
        String(
          req.params.groupId ??
          ""
        );


      const text =
        req.body?.text;


      const replyTo =
        req.body?.replyTo &&
        typeof req.body.replyTo ===
          "object"
          ? req.body.replyTo
          : null;


      const result =
        await sendUserConversationMessage(
          req.user.id,
          groupId,
          text,
          {
            replyToMsgId:
              replyTo?.msgId ??
              null,

            replyToCliMsgId:
              replyTo?.cliMsgId ??
              null,
          }
        );


      return res.json({
        success:
          true,

        sent:
          true,

        groupId:
          result.groupId,

        text:
          result.text,

        replied:
          result.replied,

        replyToMsgId:
          result.replyToMsgId,

        replyToCliMsgId:
          result.replyToCliMsgId,
      });

    } catch (error) {

      console.error(
        "[CHAT SEND] ERROR:",
        req.user.id,
        req.params.groupId,
        error
      );


      let status =
        500;


      if (
        error.code ===
          "EMPTY_MESSAGE" ||
        error.code ===
          "MESSAGE_TOO_LONG" ||
        error.code ===
          "INVALID_GROUP"
      ) {

        status =
          400;

      } else if (
        error.code ===
          "GROUP_NOT_FOUND" ||
        error.code ===
          "REPLY_TARGET_NOT_FOUND"
      ) {

        status =
          404;

      } else if (
        error.code ===
          "REPLY_TARGET_UNAVAILABLE" ||
        error.code ===
          "ZALO_NOT_LINKED"
      ) {

        status =
          409;
      }


      return res
        .status(status)
        .json({
          success:
            false,

          error:
            error?.message ??
            String(error),

          code:
            error?.code ??
            null,
        });
    }
  }
);

// ========================================
// SEND PHOTO TO ZALO GROUP
// ========================================

app.post(
  "/api/me/conversations/:groupId/messages/photo",

  requireAuth,

  (
    req,
    res
  ) => {

    // ========================================
    // MULTER SINGLE PHOTO
    // ========================================

    conversationPhotoUpload
      .single(
        "photo"
      )(
        req,
        res,

        async (
          uploadError
        ) => {

          // ========================================
          // UPLOAD ERROR
          // ========================================

          if (
            uploadError
          ) {

            console.error(
              "[CHAT PHOTO] UPLOAD ERROR:",
              req.user.id,
              uploadError
            );


            return res
              .status(400)
              .json({
                success:
                  false,

                error:
                  uploadError
                    ?.message ??
                  "Khong the nhan anh.",
              });
          }


          try {

            const file =
              req.file;


            if (
              !file ||
              !Buffer.isBuffer(
                file.buffer
              ) ||
              file.buffer.length ===
                0
            ) {

              return res
                .status(400)
                .json({
                  success:
                    false,

                  error:
                    "Chua chon anh.",
                });
            }


            // ========================================
            // DOC METADATA TU CHINH NOI DUNG FILE
            //
            // KHONG TIN HOAN TOAN VAO:
            // mimetype / ten file tu client.
            // ========================================

            const metadata =
              await sharp(
                file.buffer
              )
                .metadata();


            let format =
              String(
                metadata.format ??
                ""
              )
                .trim()
                .toLowerCase();


            // sharp tra "jpeg",
            // zca-js can filename co extension.
            if (
              format ===
                "jpeg"
            ) {

              format =
                "jpg";
            }


            // ========================================
            // BUOC DAU CHI HO TRO:
            // JPG PNG WEBP
            // ========================================

            const allowedFormats =
              new Set([
                "jpg",
                "png",
                "webp",
              ]);


            if (
              !allowedFormats.has(
                format
              )
            ) {

              return res
                .status(400)
                .json({
                  success:
                    false,

                  error:
                    "Hiện chỉ hỗ trợ ảnh JPG, PNG hoặc WEBP.",
                });
            }


            let width =
              Number(
                metadata.width
              );


            let height =
              Number(
                metadata.height
              );


            if (
              !Number.isFinite(
                width
              ) ||
              width <= 0 ||
              !Number.isFinite(
                height
              ) ||
              height <= 0
            ) {

              return res
                .status(400)
                .json({
                  success:
                    false,

                  error:
                    "Không đọc được kích thước ảnh.",
                });
            }


            // ========================================
            // EXIF ORIENTATION
            //
            // Anh doc co orientation 5-8
            // thi width / height can dao lai.
            // ========================================

            const orientation =
              Number(
                metadata.orientation ??
                1
              );


            if (
              orientation >= 5 &&
              orientation <= 8
            ) {

              const oldWidth =
                width;


              width =
                height;


              height =
                oldWidth;
            }


            const filename =
              `photo-${Date.now()}.${format}`;


            console.log(
              "[CHAT PHOTO] REQUEST:",
              req.user.id,
              req.params.groupId,
              filename,
              file.buffer.length,
              `${width}x${height}`
            );


            // ========================================
            // GUI QUA WORKER ZALO DANG CHAY
            // ========================================

            await sendUserConversationPhoto(
              req.user.id,

              req.params.groupId,

              {
                data:
                  file.buffer,

                filename,

                width,

                height,
              }
            );


            // ========================================
            // KHONG SAVE THU CONG.
            //
            // Zalo listener se nhan lai
            // chat.photo va save realtime.
            // ========================================

            return res.json({
              success:
                true,
            });

          } catch (error) {

            console.error(
              "[CHAT PHOTO] SEND ERROR:",
              req.user.id,
              req.params.groupId,
              error
            );


            const status =
              error?.code ===
                "WORKER_NOT_READY"
                ? 503
                : error?.code ===
                    "INVALID_GROUP_ID"
                  ? 400
                  : 500;


            return res
              .status(status)
              .json({
                success:
                  false,

                error:
                  error?.message ??
                  String(
                    error
                  ),
              });
          }
        }
      );
  }
);

// ========================================
// SEND PHOTO ALBUM
// 1 -> 10 PHOTOS
// ========================================

app.post(
  "/api/me/conversations/:groupId/messages/photos",

  requireAuth,

  (
    req,
    res
  ) => {

    conversationPhotoUpload
      .array(
        "photos",
        10
      )(
        req,
        res,

        async (
          uploadError
        ) => {

          if (
            uploadError
          ) {

            console.error(
              "[CHAT PHOTOS] UPLOAD ERROR:",
              req.user.id,
              uploadError
            );


            return res
              .status(400)
              .json({
                success:
                  false,

                error:
                  uploadError
                    ?.message ??
                  "Khong the nhan anh.",
              });
          }


          try {

            const files =
              Array.isArray(
                req.files
              )
                ? req.files
                : [];


            if (
              files.length ===
                0
            ) {

              return res
                .status(400)
                .json({
                  success:
                    false,

                  error:
                    "Chưa chọn ảnh.",
                });
            }


            if (
              files.length >
                10
            ) {

              return res
                .status(400)
                .json({
                  success:
                    false,

                  error:
                    "Mỗi lần chỉ gửi tối đa 10 ảnh.",
                });
            }


            const photos =
              [];


            // ========================================
            // DOC METADATA TUNG ANH
            // GIU NGUYEN THU TU USER CHON
            // ========================================

            for (
              let index = 0;
              index < files.length;
              index += 1
            ) {

              const file =
                files[index];


              if (
                !Buffer.isBuffer(
                  file.buffer
                ) ||
                file.buffer.length ===
                  0
              ) {

                return res
                  .status(400)
                  .json({
                    success:
                      false,

                    error:
                      `Ảnh ${index + 1} không hợp lệ.`,
                  });
              }


              const metadata =
                await sharp(
                  file.buffer
                )
                  .metadata();


              let format =
                String(
                  metadata.format ??
                  ""
                )
                  .trim()
                  .toLowerCase();


              if (
                format ===
                  "jpeg"
              ) {

                format =
                  "jpg";
              }


              if (
                ![
                  "jpg",
                  "png",
                  "webp",
                ].includes(
                  format
                )
              ) {

                return res
                  .status(400)
                  .json({
                    success:
                      false,

                    error:
                      `Ảnh ${index + 1} không phải JPG, PNG hoặc WEBP.`,
                  });
              }


              let width =
                Number(
                  metadata.width
                );


              let height =
                Number(
                  metadata.height
                );


              if (
                !Number.isFinite(
                  width
                ) ||
                width <= 0 ||
                !Number.isFinite(
                  height
                ) ||
                height <= 0
              ) {

                return res
                  .status(400)
                  .json({
                    success:
                      false,

                    error:
                      `Không đọc được kích thước ảnh ${index + 1}.`,
                  });
              }


              const orientation =
                Number(
                  metadata.orientation ??
                  1
                );


              if (
                orientation >= 5 &&
                orientation <= 8
              ) {

                const oldWidth =
                  width;


                width =
                  height;


                height =
                  oldWidth;
              }


              photos.push({

                data:
                  file.buffer,

                filename:
                  `photo-${Date.now()}-${index}.${format}`,

                width,

                height,
              });
            }


            console.log(
              "[CHAT PHOTOS] REQUEST:",
              req.user.id,
              req.params.groupId,
              `count=${photos.length}`
            );


            await sendUserConversationPhotos(
              req.user.id,

              req.params.groupId,

              {
                photos,
              }
            );


            return res.json({

              success:
                true,

              count:
                photos.length,
            });

          } catch (error) {

            console.error(
              "[CHAT PHOTOS] SEND ERROR:",
              req.user.id,
              req.params.groupId,
              error
            );


            return res
              .status(
                error?.code ===
                  "WORKER_NOT_READY"
                  ? 503
                  : 500
              )
              .json({
                success:
                  false,

                error:
                  error?.message ??
                  String(error),
              });
          }
        }
      );
  }
);

// ========================================
// UNDO / RECALL ZALO MESSAGE
// ========================================

app.post(
  "/api/me/conversations/:groupId/messages/undo",

  requireAuth,

  async (req, res) => {

    try {

      const groupId =
        String(
          req.params.groupId ??
          ""
        );


      const result =
        await undoUserConversationMessage(
          req.user.id,
          groupId,
          {
            msgId:
              req.body?.msgId ??
              null,

            cliMsgId:
              req.body?.cliMsgId ??
              null,
          }
        );


      return res.json({
        success:
          true,

        recalled:
          true,

        alreadyRecalled:
          result.alreadyRecalled ===
          true,
      });

    } catch (error) {

      console.error(
        "[CHAT UNDO] ERROR:",
        req.user.id,
        req.params.groupId,
        error
      );


      let status =
        500;


      if (
        error.code ===
          "INVALID_GROUP" ||
        error.code ===
          "MESSAGE_ID_REQUIRED" ||
        error.code ===
          "MESSAGE_IDS_INCOMPLETE"
      ) {

        status =
          400;

      } else if (
        error.code ===
        "NOT_OWN_MESSAGE"
      ) {

        status =
          403;

      } else if (
        error.code ===
        "MESSAGE_NOT_FOUND"
      ) {

        status =
          404;

      } else if (
        error.code ===
          "MESSAGE_UNAVAILABLE" ||
        error.code ===
          "RECALL_EXPIRED"
      ) {

        status =
          409;
      }


      return res
        .status(status)
        .json({
          success:
            false,

          error:
            error?.message ??
            String(error),

          code:
            error?.code ??
            null,
        });
    }
  }
);

// ========================================
// DELETE MESSAGE - ONLY ME
// ========================================

app.post(
  "/api/me/conversations/:groupId/messages/delete",

  requireAuth,

  async (req, res) => {

    try {

      const groupId =
        String(
          req.params.groupId ??
          ""
        );


      const result =
        await deleteUserConversationMessage(
          req.user.id,
          groupId,
          {
            msgId:
              req.body?.msgId ??
              null,

            cliMsgId:
              req.body?.cliMsgId ??
              null,
          }
        );


      // ========================================
      // BAO CHO FLUTTER XOA BUBBLE
      // ========================================

      broadcastUserEvent(
        req.user.id,
        "conversation_message_updated",
        {
          groupId,

          message:
            result.message,
        }
      );


      return res.json({
        success:
          true,

        deleted:
          true,
      });

    } catch (error) {

      console.error(
        "[CHAT DELETE] ERROR:",
        req.user.id,
        req.params.groupId,
        error
      );


      let status =
        500;


      if (
        error.code ===
          "INVALID_GROUP" ||
        error.code ===
          "MESSAGE_ID_REQUIRED" ||
        error.code ===
          "MESSAGE_IDS_INCOMPLETE" ||
        error.code ===
          "MESSAGE_SENDER_REQUIRED"
      ) {

        status =
          400;

      } else if (
        error.code ===
        "MESSAGE_NOT_FOUND"
      ) {

        status =
          404;
      }


      return res
        .status(status)
        .json({
          success:
            false,

          error:
            error?.message ??
            String(error),

          code:
            error?.code ??
            null,
        });
    }
  }
);

// ========================================
// PIN / UNPIN CONVERSATION
// ========================================

app.patch(
  "/api/me/conversations/:groupId/pin",

  requireAuth,

  (
    req,
    res
  ) => {

    try {

      const groupId =
        String(
          req.params.groupId ??
          ""
        ).trim();


      if (!groupId) {

        return res
          .status(400)
          .json({
            success:
              false,

            error:
              "Group ID khong hop le.",
          });
      }


      const pinned =
        req.body?.pinned;


      if (
        typeof pinned !==
        "boolean"
      ) {

        return res
          .status(400)
          .json({
            success:
              false,

            error:
              "pinned phai la boolean.",
          });
      }


      const conversation =
        setUserConversationPinned(
          req.user.id,
          groupId,
          pinned
        );


      if (!conversation) {

        return res
          .status(404)
          .json({
            success:
              false,

            error:
              "Khong tim thay hoi thoai.",
          });
      }


      // ========================================
      // REALTIME CHO CAC THIET BI KHAC
      // ========================================

      broadcastUserEvent(
        req.user.id,
        "conversation_pinned",
        {
          groupId,

          pinned:
            conversation.pinned,

          pinnedAt:
            conversation.pinnedAt,
        }
      );


      return res.json({
        success:
          true,

        conversation,
      });

    } catch (error) {

      console.error(
        "[CONVERSATION PIN] ERROR:",
        req.user.id,
        req.params.groupId,
        error
      );


      return res
        .status(500)
        .json({
          success:
            false,

          error:
            error?.message ??
            String(error),
        });
    }
  }
);

// ========================================
// START SERVER
// ========================================

async function startServer() {
  console.log("");
  console.log("==============================");
  console.log("      ZAUTO BACKEND V1");
  console.log("==============================");
  console.log("");

  try {
    initFirebaseAdmin();

    console.log(
      "[SERVER] Firebase ready"
    );

    console.log(
      "[SERVER] Per-user Zalo mode enabled"
    );

    // ========================================
    // NETWORK WATCHDOG
    // ========================================

    startNetworkWatchdog();

    // ========================================
    // NETWORK WATCHDOG STATUS
    // ========================================

    app.get(
      "/api/me/network/status",

      requireAuth,

      (req, res) => {

        res.json({
          success: true,

          network:
            getNetworkWatchdogStatus(),
        });
      }
    );


    // ========================================
    // USER ZALO WORKERS
    // ========================================

    startAllUserWorkers()
      .catch(
        error => {

          console.error(
            "[USER WORKERS] STARTUP ERROR:",
            error
          );
        }
      );
  } catch (error) {
    console.error(
      "[SERVER] Startup error:"
    );

    console.error(error);
  }

  const httpServer =
    http.createServer(app);

  initWebSocket(httpServer);

  httpServer.listen(
    PORT,
    "0.0.0.0",
    () => {
      console.log("");
      console.log(
        `[SERVER] Running on http://localhost:${PORT}`
      );

      console.log(
        `[SERVER] WebSocket: ws://localhost:${PORT}/ws`
      );

      console.log(
        `[SERVER] Health: http://localhost:${PORT}/health`
      );

      console.log(
        `[SERVER] Zalo: http://localhost:${PORT}/api/zalo/status`
      );
    }
  );
}

startServer();