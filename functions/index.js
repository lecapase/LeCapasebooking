const {setGlobalOptions} = require("firebase-functions/v2");
const {
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");

const logger = require("firebase-functions/logger");

const {
  initializeApp,
} = require("firebase-admin/app");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

const {
  getMessaging,
} = require("firebase-admin/messaging");

// ============================================================
// FIREBASE ADMIN
// ============================================================

initializeApp();

const db = getFirestore();

// ============================================================
// CONFIGURAZIONE GLOBALE
// ============================================================

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

// ============================================================
// COSTANTI
// ============================================================

const BOOKINGS_COLLECTION = "bookings";
const ADMINS_COLLECTION = "admins";

const ANDROID_CHANNEL_ID =
  "le_capase_bookings_high";

// ============================================================
// FORMATTA NOME CLIENTE
// ============================================================

function customerName(data) {
  const nome =
    typeof data.nome === "string" ?
      data.nome.trim() :
      "";

  const cognome =
    typeof data.cognome === "string" ?
      data.cognome.trim() :
      "";

  const completeName =
    `${nome} ${cognome}`.trim();

  return completeName || "Cliente";
}

// ============================================================
// FORMATTA NUMERO PERSONE
// ============================================================

function guestsLabel(guests) {
  if (guests === 1) {
    return "1 persona";
  }

  return `${guests} persone`;
}

// ============================================================
// FORMATTA DATA
// ============================================================

function formatDate(dateKey) {
  if (
    typeof dateKey !== "string" ||
    dateKey.length !== 10
  ) {
    return dateKey || "";
  }

  const parts = dateKey.split("-");

  if (parts.length !== 3) {
    return dateKey;
  }

  const year = Number(parts[0]);
  const month = Number(parts[1]);
  const day = Number(parts[2]);

  if (
    !Number.isInteger(year) ||
    !Number.isInteger(month) ||
    !Number.isInteger(day)
  ) {
    return dateKey;
  }

  const months = [
    "gennaio",
    "febbraio",
    "marzo",
    "aprile",
    "maggio",
    "giugno",
    "luglio",
    "agosto",
    "settembre",
    "ottobre",
    "novembre",
    "dicembre",
  ];

  if (month < 1 || month > 12) {
    return dateKey;
  }

  return `${day} ${months[month - 1]}`;
}

// ============================================================
// LEGGE TUTTI I TOKEN DEGLI ADMIN
// ============================================================

async function getAdminTokens() {
  const snapshot =
    await db
        .collection(ADMINS_COLLECTION)
        .get();

  const tokens = new Set();

  snapshot.forEach((document) => {
    const data = document.data();

    const fcmTokens =
      Array.isArray(data.fcmTokens) ?
        data.fcmTokens :
        [];

    for (const token of fcmTokens) {
      if (
        typeof token === "string" &&
        token.trim().length > 0
      ) {
        tokens.add(token.trim());
      }
    }
  });

  return Array.from(tokens);
}

// ============================================================
// COSTRUISCE IL TESTO DELLA NOTIFICA
// ============================================================

function buildNotification(data) {
  const guests =
    Number.isInteger(data.guests) ?
      data.guests :
      Number(data.guests || 0);

  const name =
    customerName(data);

  const date =
    formatDate(data.dateKey);

  const time =
    typeof data.time === "string" ?
      data.time :
      "";

  const confirmed =
    data.status === "confirmed";

  const title =
    confirmed ?
      "Nuova prenotazione confermata" :
      "Nuova richiesta da confermare";

  const parts = [
    name,
    guestsLabel(guests),
    date,
    time,
  ].filter(
      (value) =>
        typeof value === "string" &&
        value.trim().length > 0,
  );

  const body =
    parts.join(" · ");

  return {
    title,
    body,
  };
}

// ============================================================
// PUSH AUTOMATICA NUOVA PRENOTAZIONE
// ============================================================

exports.onNewBooking =
  onDocumentCreated(
      `${BOOKINGS_COLLECTION}/{bookingId}`,
      async (event) => {
        const snapshot =
          event.data;

        if (!snapshot) {
          logger.warn(
              "Evento senza documento prenotazione.",
          );

          return;
        }

        const data =
          snapshot.data();

        const bookingId =
          event.params.bookingId;

        logger.info(
            "Nuova prenotazione rilevata.",
            {
              bookingId,
              guests: data.guests,
              status: data.status,
            },
        );

        // ====================================================
        // SICUREZZA:
        // NOTIFICHIAMO SOLO PRENOTAZIONI CLIENTE
        // ====================================================

        if (data.source !== "customer") {
          logger.info(
              "Prenotazione non proveniente dal cliente. " +
              "Push ignorata.",
              {
                bookingId,
                source: data.source,
              },
          );

          return;
        }

        // ====================================================
        // RECUPERA TOKEN ADMIN
        // ====================================================

        const tokens =
          await getAdminTokens();

        if (tokens.length === 0) {
          logger.warn(
              "Nessun token FCM admin disponibile.",
              {
                bookingId,
              },
          );

          return;
        }

        // ====================================================
        // TESTO PUSH
        // ====================================================

        const notification =
          buildNotification(data);

        // ====================================================
        // MESSAGGIO FCM
        // ====================================================

        const message = {
          tokens,

          notification: {
            title:
              notification.title,

            body:
              notification.body,
          },

          data: {
            type:
              "new_booking",

            bookingId:
              String(bookingId),

            status:
              String(
                  data.status || "",
              ),

            guests:
              String(
                  data.guests || "",
              ),

            dateKey:
              String(
                  data.dateKey || "",
              ),

            time:
              String(
                  data.time || "",
              ),

            service:
              String(
                  data.service || "",
              ),
          },

          android: {
            priority: "high",

            notification: {
              channelId:
                ANDROID_CHANNEL_ID,

              sound:
                "default",

              priority:
                "high",

              visibility:
                "public",

              defaultVibrateTimings:
                true,
            },
          },
        };

        // ====================================================
        // INVIA PUSH
        // ====================================================

        const response =
          await getMessaging()
              .sendEachForMulticast(
                  message,
              );

        logger.info(
            "Invio push completato.",
            {
              bookingId,
              successCount:
                response.successCount,

              failureCount:
                response.failureCount,
            },
        );

        // ====================================================
        // LOG ERRORI SINGOLI TOKEN
        // ====================================================

        response.responses.forEach(
            (result, index) => {
              if (!result.success) {
                logger.warn(
                    "Invio token FCM fallito.",
                    {
                      bookingId,
                      tokenIndex:
                        index,
                      errorCode:
                        result.error
                            ?.code,
                      errorMessage:
                        result.error
                            ?.message,
                    },
                );
              }
            },
        );

        // ====================================================
        // SEGNA LA PRENOTAZIONE COME NOTIFICATA
        //
        // Basta almeno un dispositivo raggiunto.
        // ====================================================

        if (response.successCount > 0) {
          await snapshot.ref.update({
            adminNotificationSent:
              true,

            adminNotificationSentAt:
              FieldValue.serverTimestamp(),

            updatedAt:
              FieldValue.serverTimestamp(),
          });

          logger.info(
              "Prenotazione marcata come notificata.",
              {
                bookingId,
              },
          );
        }
      },
  );