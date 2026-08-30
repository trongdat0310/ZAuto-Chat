import {
  WebSocketServer,
  WebSocket,
} from "ws";

import jwt from "jsonwebtoken";

import {
  JWT_SECRET,
} from "../config/env.js";

import {
  isTokenRevoked,
} from "../auth/revoked-token-store.js";

import {
  findUserById,
} from "../users/user-store.js";


let wss = null;


// userId -> Set<WebSocket>
const socketsByUser =
  new Map();


// ========================================
// ADD SOCKET
// ========================================

function addUserSocket(
  userId,
  socket
) {
  const key =
    String(userId);


  if (
    !socketsByUser.has(key)
  ) {
    socketsByUser.set(
      key,
      new Set()
    );
  }


  socketsByUser
    .get(key)
    .add(socket);
}


// ========================================
// REMOVE SOCKET
// ========================================

function removeUserSocket(
  socket
) {
  const userId =
    socket.userId;


  if (!userId) {
    return;
  }


  const sockets =
    socketsByUser.get(
      String(userId)
    );


  if (!sockets) {
    return;
  }


  sockets.delete(socket);


  if (
    sockets.size === 0
  ) {
    socketsByUser.delete(
      String(userId)
    );
  }
}


// ========================================
// VERIFY JWT
// ========================================

function authenticateToken(
  token
) {
  if (
    typeof token !==
      "string" ||
    token.length < 10
  ) {
    throw new Error(
      "JWT token khong hop le."
    );
  }


  const payload =
    jwt.verify(
      token,
      JWT_SECRET
    );


  if (
    isTokenRevoked(
      payload.jti
    )
  ) {
    throw new Error(
      "Phien dang nhap da bi dang xuat."
    );
  }


  const userId =
    String(
      payload.sub ?? ""
    );


  if (!userId) {
    throw new Error(
      "JWT khong co userId."
    );
  }


  const user =
    findUserById(
      userId
    );


  if (!user) {
    throw new Error(
      "Tai khoan khong ton tai."
    );
  }


  return user;
}


// ========================================
// SEND JSON
// ========================================

function sendJson(
  socket,
  data
) {
  if (
    socket.readyState !==
    WebSocket.OPEN
  ) {
    return;
  }


  socket.send(
    JSON.stringify(data)
  );
}


// ========================================
// INITIALIZE
// ========================================

export function initWebSocket(
  httpServer
) {
  wss =
    new WebSocketServer({
      server:
        httpServer,

      path:
        "/ws",
    });


  wss.on(
    "connection",

    (socket, request) => {

      socket.userId =
        null;

      socket.authenticated =
        false;


      console.log(
        "[WS] Connection:",
        request.socket.remoteAddress
      );


      // ========================================
      // PHAI AUTH TRONG 10 GIAY
      // ========================================

      const authTimeout =
        setTimeout(
          () => {

            if (
              socket.authenticated !==
              true
            ) {
              socket.close(
                4001,
                "Authentication timeout"
              );
            }

          },
          10000
        );


      sendJson(
        socket,
        {
          type:
            "auth_required",

          at:
            new Date()
              .toISOString(),
        }
      );


      // ========================================
      // MESSAGE FROM CLIENT
      // ========================================

      socket.on(
        "message",

        (raw) => {

          let event;


          try {
            event =
              JSON.parse(
                raw.toString()
              );

          } catch {
            socket.close(
              4002,
              "Invalid JSON"
            );

            return;
          }


          // Sau khi auth xong,
          // hien tai khong can xu ly
          // message client khac.
          if (
            socket.authenticated ===
            true
          ) {
            return;
          }


          if (
            event?.type !==
            "auth"
          ) {
            socket.close(
              4003,
              "Authentication required"
            );

            return;
          }


          try {

            const user =
              authenticateToken(
                event.token
              );


            socket.userId =
              String(
                user.id
              );

            socket.authenticated =
              true;


            clearTimeout(
              authTimeout
            );


            addUserSocket(
              socket.userId,
              socket
            );


            console.log(
              "[WS] AUTHENTICATED:",
              socket.userId
            );


            sendJson(
              socket,
              {
                type:
                  "authenticated",

                data: {
                  userId:
                    socket.userId,
                },

                at:
                  new Date()
                    .toISOString(),
              }
            );

          } catch (error) {

            console.error(
              "[WS] AUTH ERROR:",
              error?.message ??
              error
            );


            sendJson(
              socket,
              {
                type:
                  "auth_error",

                data: {
                  message:
                    "Phien dang nhap khong hop le.",
                },
              }
            );


            socket.close(
              4004,
              "Authentication failed"
            );
          }
        }
      );


      // ========================================
      // CLOSE
      // ========================================

      socket.on(
        "close",
        () => {

          clearTimeout(
            authTimeout
          );


          removeUserSocket(
            socket
          );


          console.log(
            "[WS] Disconnected:",
            socket.userId ??
            "unauthenticated"
          );
        }
      );


      socket.on(
        "error",
        (error) => {

          console.error(
            "[WS] ERROR:",
            socket.userId ??
            "unauthenticated",
            error
          );
        }
      );
    }
  );


  console.log(
    "[WS] User-scoped WebSocket initialized"
  );
}


// ========================================
// BROADCAST CHI CHO 1 USER
// ========================================

export function broadcastUserEvent(
  userId,
  type,
  data
) {
  const key =
    String(userId);


  const sockets =
    socketsByUser.get(
      key
    );


  if (
    !sockets ||
    sockets.size === 0
  ) {
    console.log(
      "[WS] No realtime client:",
      key
    );

    return 0;
  }


  const payload =
    JSON.stringify({
      type,
      data,

      at:
        new Date()
          .toISOString(),
    });


  let sent = 0;


  for (
    const socket
    of sockets
  ) {

    if (
      socket.readyState ===
        WebSocket.OPEN &&
      socket.authenticated ===
        true
    ) {
      socket.send(
        payload
      );

      sent += 1;
    }
  }


  console.log(
    `[WS] USER ${key}: ${type} -> ${sent} client(s)`
  );


  return sent;
}


// ========================================
// LEGACY GLOBAL BROADCAST
// KHONG CHO PHAT DU LIEU GLOBAL NUA.
// ========================================

export function broadcastEvent() {
  console.warn(
    "[WS] Global broadcast blocked."
  );

  return 0;
}