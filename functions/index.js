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
const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");

function customerName(data) {
  const nome =
    typeof data.nome === "string" ?
      data.nome.trim() :
      "";

  const cognome =
    typeof data.cognome === "string" ?
      data.cognome.trim() :
      "";

  return `${nome} ${cognome}`.trim() || "Cliente";
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

function bookingDetails(data) {
  const guests =
    Number.isInteger(data.guests) ?
      data.guests :
      Number(data.guests || 0);

  return {
    name: customerName(data),
    guests,
    guestsText: guestsLabel(guests),
    date: formatDate(data.dateKey),
    time:
      typeof data.time === "string" ?
        data.time :
        "",
    service: serviceLabel(data.service),
  };
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
  const details = bookingDetails(data);

  const confirmed =
    data.status === "confirmed";

  const parts = [
    details.name,
    details.guestsText,
    details.date,
    details.time,
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
        const snapshot = event.data;

        if (!snapshot) {
          logger.warn(
              "Evento senza documento prenotazione.",
          );

          return;
        }

        const data = snapshot.data();

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

        const response =
          await getMessaging()
              .sendEachForMulticast({
                tokens,

                notification:
                  buildNotification(data),

                data: {
                  type:
                    "new_booking",

                  bookingId:
                    String(bookingId),

                  status:
                    String(data.status || ""),

                  guests:
                    String(data.guests || ""),

                  dateKey:
                    String(data.dateKey || ""),

                  time:
                    String(data.time || ""),

                  service:
                    String(data.service || ""),
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
// CONFIGURAZIONE DELLE EMAIL
// ============================================================

const EMAIL_TYPES = {
  received: {
    status:
      "pending",

    sentField:
      "requestReceivedEmailSent",

    sentAtField:
      "requestReceivedEmailSentAt",

    processingField:
      "requestReceivedEmailProcessing",

    processingAtField:
      "requestReceivedEmailProcessingAt",

    errorField:
      "requestReceivedEmailLastError",

    messageIdField:
      "requestReceivedEmailMessageId",

    subject:
      "Richiesta di prenotazione ricevuta – Le Capase",

    title:
      "Richiesta ricevuta",

    opening:
      "abbiamo ricevuto la tua richiesta di prenotazione.",

    notice:
      "La richiesta è stata presa in carico e riceverai " +
      "la conferma definitiva il prima possibile.",

    warning:
      "Attenzione: la prenotazione non è ancora confermata.",

    closing:
      "Ti contatteremo al più presto.",
  },

  confirmed: {
    status:
      "confirmed",

    sentField:
      "confirmationEmailSent",

    sentAtField:
      "confirmationEmailSentAt",

    processingField:
      "confirmationEmailProcessing",

    processingAtField:
      "confirmationEmailProcessingAt",

    errorField:
      "confirmationEmailLastError",

    messageIdField:
      "confirmationEmailMessageId",

    subject:
      "Conferma prenotazione – Le Capase",

    title:
      "Prenotazione confermata",

    opening:
      "la tua prenotazione presso Le Capase è confermata.",

    notice:
      "Il tuo tavolo è stato riservato.",

    warning:
      "",

    closing:
      "Ti aspettiamo!",
  },

  rejected: {
    status:
      "rejected",

    sentField:
      "rejectionEmailSent",

    sentAtField:
      "rejectionEmailSentAt",

    processingField:
      "rejectionEmailProcessing",

    processingAtField:
      "rejectionEmailProcessingAt",

    errorField:
      "rejectionEmailLastError",

    messageIdField:
      "rejectionEmailMessageId",

    subject:
      "Richiesta di prenotazione non accettata – Le Capase",

    title:
      "Richiesta non accettata",

    opening:
      "siamo spiacenti di comunicarti che non possiamo " +
      "confermare la tua richiesta di prenotazione.",

    notice:
      "Per esigenze organizzative interne non ci è possibile " +
      "accogliere la richiesta indicata.",

    warning:
      "",

    closing:
      "Ci scusiamo per il disagio.",
  },

  cancelled: {
    status:
      "cancelled",

    sentField:
      "cancellationEmailSent",

    sentAtField:
      "cancellationEmailSentAt",

    processingField:
      "cancellationEmailProcessing",

    processingAtField:
      "cancellationEmailProcessingAt",

    errorField:
      "cancellationEmailLastError",

    messageIdField:
      "cancellationEmailMessageId",

    subject:
      "Prenotazione annullata – Le Capase",

    title:
      "Prenotazione annullata",

    opening:
      "siamo spiacenti di comunicarti che la tua " +
      "prenotazione è stata annullata.",

    notice:
      "Per problemi organizzativi interni non ci è possibile " +
      "mantenere la prenotazione indicata.",

    warning:
      "",

    closing:
      "Ci scusiamo sinceramente per il disagio.",
  },
};

// ============================================================
// BLOCCO CONTRO INVII EMAIL DUPLICATI
// ============================================================

async function claimEmail(
    reference,
    type,
) {
  const config =
    EMAIL_TYPES[type];

  if (!config) {
    return null;
  }

  return db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(reference);

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
          data.status !== config.status ||
          email.length === 0 ||
          data[config.sentField] === true ||
          data[config.processingField] === true
        ) {
          return null;
        }

        transaction.update(
            reference,
            {
              [config.processingField]:
                true,

              [config.processingAtField]:
                FieldValue.serverTimestamp(),

              [config.errorField]:
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
// CONTENUTO DELLE EMAIL
// ============================================================

function buildEmail(
    data,
    type,
) {
  const config =
    EMAIL_TYPES[type];

  const details =
    bookingDetails(data);

  const textLines = [
    `Gentile ${details.name},`,
    "",
    config.opening,
    "",
    `Data: ${details.date}`,
    `Orario: ${details.time}`,
    `Servizio: ${details.service}`,
    `Ospiti: ${details.guestsText}`,
    "",
    config.notice,
  ];

  if (config.warning) {
    textLines.push(
        "",
        config.warning,
    );
  }

  textLines.push(
      "",
      config.closing,
      "",
      "Le Capase – Ristorante Pizzeria",
  );

  const warningHtml =
    config.warning ?
      `
        <p style="
          padding:12px;
          background:#fff4d6;
          border-left:4px solid #c8a45d;
        ">
          <strong>
            ${escapeHtml(config.warning)}
          </strong>
        </p>
      ` :
      "";

  const html = `
    <div style="
      font-family:Arial,sans-serif;
      max-width:600px;
      margin:auto;
      color:#222;
      line-height:1.6;
    ">
      <h2 style="color:#a7863d">
        ${escapeHtml(config.title)}
      </h2>

      <p>
        Gentile
        <strong>
          ${escapeHtml(details.name)}
        </strong>,
      </p>

      <p>
        ${escapeHtml(config.opening)}
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
              ${escapeHtml(details.date)}
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
              ${escapeHtml(details.time)}
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
              ${escapeHtml(details.service)}
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
              ${escapeHtml(details.guestsText)}
            </strong>
          </td>
        </tr>
      </table>

      <p>
        ${escapeHtml(config.notice)}
      </p>

      ${warningHtml}

      <p>
        ${escapeHtml(config.closing)}
      </p>

      <p>
        <strong>
          Le Capase – Ristorante Pizzeria
        </strong>
      </p>
    </div>
  `;

  return {
    text:
      textLines.join("\n"),

    html,
  };
}

// ============================================================
// INVIO DELL'EMAIL
// ============================================================

async function sendBookingEmail(
    snapshot,
    bookingId,
    type,
) {
  const config =
    EMAIL_TYPES[type];

  const data =
    await claimEmail(
        snapshot.ref,
        type,
    );

  if (
    !config ||
    !data
  ) {
    return;
  }

  const email =
    data.email.trim();

  const content =
    buildEmail(
        data,
        type,
    );

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
          config.subject,

        text:
          content.text,

        html:
          content.html,
      });

    await snapshot.ref.update({
      [config.sentField]:
        true,

      [config.sentAtField]:
        FieldValue.serverTimestamp(),

      [config.processingField]:
        false,

      [config.messageIdField]:
        result.messageId || null,

      updatedAt:
        FieldValue.serverTimestamp(),
    });

    logger.info(
        "Email prenotazione inviata.",
        {
          bookingId,
          type,
        },
    );
  } catch (error) {
    await snapshot.ref.update({
      [config.processingField]:
        false,

      [config.errorField]:
        String(error).slice(
            0,
            500,
        ),

      updatedAt:
        FieldValue.serverTimestamp(),
    });

    logger.error(
        "Invio email prenotazione fallito.",
        {
          bookingId,
          type,
          error,
        },
    );

    throw error;
  }
}

// ============================================================
// EMAIL ALLA CREAZIONE
//
// 1-4 PERSONE:
// CONFERMA AUTOMATICA
//
// DA 5 PERSONE:
// RICHIESTA PRESA IN CARICO
// ============================================================

exports.onCustomerBookingCreated =
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

        const data =
          snapshot.data();

        const status =
          data.status;

        const bookingId =
          event.params.bookingId;

        if (status === "confirmed") {
          await sendBookingEmail(
              snapshot,
              bookingId,
              "confirmed",
          );

          return;
        }

        if (status === "pending") {
          await sendBookingEmail(
              snapshot,
              bookingId,
              "received",
          );
        }
      },
  );

// ============================================================
// EMAIL QUANDO IL GESTIONALE CAMBIA LO STATO
//
// PENDING -> CONFIRMED:
// EMAIL DI CONFERMA
//
// PENDING -> REJECTED:
// EMAIL DI RIFIUTO
//
// CONFIRMED -> CANCELLED:
// EMAIL DI ANNULLAMENTO
// ============================================================

exports.onCustomerBookingStatusChanged =
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

        if (
          !before ||
          !after
        ) {
          return;
        }

        const oldStatus =
          before.data().status;

        const newStatus =
          after.data().status;

        if (oldStatus === newStatus) {
          return;
        }

        const bookingId =
          event.params.bookingId;

        if (newStatus === "confirmed") {
          await sendBookingEmail(
              after,
              bookingId,
              "confirmed",
          );

          return;
        }

        if (newStatus === "rejected") {
          await sendBookingEmail(
              after,
              bookingId,
              "rejected",
          );

          return;
        }

        if (newStatus === "cancelled") {
          await sendBookingEmail(
              after,
              bookingId,
              "cancelled",
          );
        }
      },
  );