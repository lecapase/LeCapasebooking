const {setGlobalOptions} = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const nodemailer = require("nodemailer");

initializeApp();

const db = getFirestore();

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

const BOOKINGS_COLLECTION = "bookings";
const ADMINS_COLLECTION = "admins";
const ANDROID_CHANNEL_ID = "le_capase_bookings_high";

const gmailUser = defineSecret("GMAIL_USER");
const gmailAppPassword = defineSecret(
    "GMAIL_APP_PASSWORD",
);

function customerName(data) {
  const nome =
    typeof data.nome === "string" ?
      data.nome.trim() :
      "";

  const cognome =
    typeof data.cognome === "string" ?
      data.cognome.trim() :
      "";

  return `${nome} ${cognome}`.trim() ||
    "Cliente";
}

function guestsLabel(guests) {
  return guests === 1 ?
    "1 persona" :
    `${guests} persone`;
}

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

  if (
    !Number.isInteger(year) ||
    !Number.isInteger(month) ||
    !Number.isInteger(day) ||
    month < 1 ||
    month > 12
  ) {
    return dateKey;
  }

  return `${day} ${months[month - 1]} ${year}`;
}

function serviceLabel(service) {
  switch (service) {
    case "lunch":
      return "Pranzo";

    case "dinner":
      return "Cena";

    default:
      return typeof service === "string" ?
        service :
        "";
  }
}

function escapeHtml(value) {
  return String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll("\"", "&quot;")
      .replaceAll("'", "&#039;");
}

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

function buildNotification(data) {
  const guests =
    Number.isInteger(data.guests) ?
      data.guests :
      Number(data.guests || 0);

  const confirmed =
    data.status === "confirmed";

  const parts = [
    customerName(data),
    guestsLabel(guests),
    formatDate(data.dateKey),
    typeof data.time === "string" ?
      data.time :
      "",
  ].filter(
      (value) =>
        typeof value === "string" &&
        value.trim().length > 0,
  );

  return {
    title:
      confirmed ?
        "Nuova prenotazione confermata" :
        "Nuova richiesta da confermare",

    body:
      parts.join(" · "),
  };
}

// ============================================================
// NOTIFICA PUSH ALL'AMMINISTRATORE
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

        if (data.source !== "customer") {
          logger.info(
              "Prenotazione non cliente: push ignorata.",
              {
                bookingId,
              },
          );

          return;
        }

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

        const notification =
          buildNotification(data);

        const response =
          await getMessaging()
              .sendEachForMulticast({
                tokens,

                notification,

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
                  priority:
                    "high",

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
              });

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
                        result.error?.code,

                      errorMessage:
                        result.error?.message,
                    },
                );
              }
            },
        );

        if (response.successCount > 0) {
          await snapshot.ref.update({
            adminNotificationSent:
              true,

            adminNotificationSentAt:
              FieldValue.serverTimestamp(),

            updatedAt:
              FieldValue.serverTimestamp(),
          });
        }
      },
  );

// ============================================================
// BLOCCA L'INVIO DOPPIO DELL'EMAIL
// ============================================================

async function claimConfirmationEmail(
    reference,
) {
  return db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(
              reference,
          );

        if (!snapshot.exists) {
          return null;
        }

        const data =
          snapshot.data();

        const email =
          typeof data.email === "string" ?
            data.email.trim() :
            "";

        if (
          data.source !== "customer" ||
          data.status !== "confirmed" ||
          email.length === 0 ||
          data.confirmationEmailSent === true ||
          data.confirmationEmailProcessing === true
        ) {
          return null;
        }

        transaction.update(
            reference,
            {
              confirmationEmailProcessing:
                true,

              confirmationEmailProcessingAt:
                FieldValue.serverTimestamp(),

              confirmationEmailLastError:
                FieldValue.delete(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
        );

        return data;
      },
  );
}

// ============================================================
// CONTENUTO EMAIL DI CONFERMA
// ============================================================

function buildConfirmationEmail(data) {
  const name =
    customerName(data);

  const guests =
    Number.isInteger(data.guests) ?
      data.guests :
      Number(data.guests || 0);

  const date =
    formatDate(data.dateKey);

  const time =
    typeof data.time === "string" ?
      data.time :
      "";

  const service =
    serviceLabel(data.service);

  const text = [
    `Gentile ${name},`,
    "",
    "la tua prenotazione presso Le Capase è confermata.",
    "",
    `Data: ${date}`,
    `Orario: ${time}`,
    `Servizio: ${service}`,
    `Ospiti: ${guestsLabel(guests)}`,
    "",
    "Per modifiche o cancellazioni puoi rispondere a questa email.",
    "",
    "Ti aspettiamo!",
    "Le Capase – Ristorante Pizzeria",
  ].join("\n");

  const html = `
    <div style="
      font-family:Arial,sans-serif;
      max-width:600px;
      margin:auto;
      color:#222;
      line-height:1.6;
    ">
      <h2 style="color:#a7863d">
        Prenotazione confermata
      </h2>

      <p>
        Gentile
        <strong>${escapeHtml(name)}</strong>,
      </p>

      <p>
        La tua prenotazione presso
        <strong>Le Capase</strong>
        è confermata.
      </p>

      <table style="
        border-collapse:collapse;
        width:100%;
        margin:20px 0;
      ">
        <tr>
          <td style="
            padding:8px;
            border-bottom:1px solid #ddd;
          ">
            Data
          </td>

          <td style="
            padding:8px;
            border-bottom:1px solid #ddd;
          ">
            <strong>
              ${escapeHtml(date)}
            </strong>
          </td>
        </tr>

        <tr>
          <td style="
            padding:8px;
            border-bottom:1px solid #ddd;
          ">
            Orario
          </td>

          <td style="
            padding:8px;
            border-bottom:1px solid #ddd;
          ">
            <strong>
              ${escapeHtml(time)}
            </strong>
          </td>
        </tr>

        <tr>
          <td style="
            padding:8px;
            border-bottom:1px solid #ddd;
          ">
            Servizio
          </td>

          <td style="
            padding:8px;
            border-bottom:1px solid #ddd;
          ">
            <strong>
              ${escapeHtml(service)}
            </strong>
          </td>
        </tr>

        <tr>
          <td style="
            padding:8px;
            border-bottom:1px solid #ddd;
          ">
            Ospiti
          </td>

          <td style="
            padding:8px;
            border-bottom:1px solid #ddd;
          ">
            <strong>
              ${escapeHtml(
                  guestsLabel(guests),
              )}
            </strong>
          </td>
        </tr>
      </table>

      <p>
        Per modifiche o cancellazioni
        puoi rispondere a questa email.
      </p>

      <p>Ti aspettiamo!</p>

      <p>
        <strong>
          Le Capase – Ristorante Pizzeria
        </strong>
      </p>
    </div>
  `;

  return {
    text,
    html,
  };
}

// ============================================================
// INVIO EMAIL AUTOMATICA
// ============================================================

async function sendConfirmationEmail(
    snapshot,
    bookingId,
) {
  const data =
    await claimConfirmationEmail(
        snapshot.ref,
    );

  if (!data) {
    return;
  }

  const email =
    data.email.trim();

  const content =
    buildConfirmationEmail(data);

  const sender =
    gmailUser.value();

  try {
    const transporter =
      nodemailer.createTransport({
        service:
          "gmail",

        auth: {
          user:
            sender,

          pass:
            gmailAppPassword.value(),
        },
      });

    const result =
      await transporter.sendMail({
        from:
          `"Le Capase Prenotazioni" <${sender}>`,

        replyTo:
          sender,

        to:
          email,

        subject:
          "Conferma prenotazione – Le Capase",

        text:
          content.text,

        html:
          content.html,
      });

    await snapshot.ref.update({
      confirmationEmailSent:
        true,

      confirmationEmailSentAt:
        FieldValue.serverTimestamp(),

      confirmationEmailProcessing:
        false,

      confirmationEmailMessageId:
        result.messageId || null,

      updatedAt:
        FieldValue.serverTimestamp(),
    });

    logger.info(
        "Email di conferma inviata.",
        {
          bookingId,
        },
    );
  } catch (error) {
    await snapshot.ref.update({
      confirmationEmailProcessing:
        false,

      confirmationEmailLastError:
        String(error).slice(
            0,
            500,
        ),

      updatedAt:
        FieldValue.serverTimestamp(),
    });

    logger.error(
        "Invio email di conferma fallito.",
        {
          bookingId,
          error,
        },
    );

    throw error;
  }
}

// ============================================================
// EMAIL PER PRENOTAZIONE 1-4 PERSONE
// CONFERMATA AUTOMATICAMENTE ALLA CREAZIONE
// ============================================================

exports.onConfirmedBookingCreated =
  onDocumentCreated(
      {
        document:
          `${BOOKINGS_COLLECTION}/{bookingId}`,

        secrets: [
          gmailUser,
          gmailAppPassword,
        ],
      },
      async (event) => {
        const snapshot =
          event.data;

        if (!snapshot) {
          return;
        }

        await sendConfirmationEmail(
            snapshot,
            event.params.bookingId,
        );
      },
  );

// ============================================================
// EMAIL QUANDO IL GESTIONALE CONFERMA UNA RICHIESTA 5+
// ============================================================

exports.onBookingConfirmed =
  onDocumentUpdated(
      {
        document:
          `${BOOKINGS_COLLECTION}/{bookingId}`,

        secrets: [
          gmailUser,
          gmailAppPassword,
        ],
      },
      async (event) => {
        const before =
          event.data?.before;

        const after =
          event.data?.after;

        if (!before || !after) {
          return;
        }

        const oldStatus =
          before.data().status;

        const newStatus =
          after.data().status;

        if (
          oldStatus === "confirmed" ||
          newStatus !== "confirmed"
        ) {
          return;
        }

        await sendConfirmationEmail(
            after,
            event.params.bookingId,
        );
      },
  );