const crypto = require("crypto");

const {
  setGlobalOptions,
} = require("firebase-functions/v2");

const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const {
  onSchedule,
} = require("firebase-functions/v2/scheduler");

const {
  onRequest,
} = require("firebase-functions/v2/https");

const {
  defineSecret,
} = require("firebase-functions/params");

const logger =
  require("firebase-functions/logger");

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

const {
  getStorage,
  getDownloadURL,
} = require("firebase-admin/storage");

const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");
const nodemailer =
  require("nodemailer");

initializeApp();

const db =
  getFirestore();

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

const BOOKINGS_COLLECTION =
  "bookings";

const ADMINS_COLLECTION =
  "admins";

const NOTIFICATION_DEVICES_COLLECTION =
  "notification_devices";

const CUSTOMER_PROFILES_COLLECTION =
  "customer_profiles";

const EMAIL_EVENTS_COLLECTION =
  "_system_email_events";

const WHATSAPP_EVENTS_COLLECTION =
  "_system_whatsapp_events";

const ANDROID_CHANNEL_ID =
  "le_capase_bookings_high";

const gmailUser =
  defineSecret("GMAIL_USER");

const gmailAppPassword =
  defineSecret("GMAIL_APP_PASSWORD");

const dialog360ApiKey =
  defineSecret("DIALOG360_API_KEY");
const dialog360WebhookToken =
  defineSecret("DIALOG360_WEBHOOK_TOKEN");

// ============================================================
// UTILITÀ GENERALI
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

  const parts =
    dateKey.split("-");

  if (parts.length !== 3) {
    return dateKey;
  }

  const year =
    Number(parts[0]);

  const month =
    Number(parts[1]);

  const day =
    Number(parts[2]);

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

function normalizeEmail(email) {
  return typeof email === "string" ?
    email.trim().toLowerCase() :
    "";
}

function normalizePhone(phone) {
  if (typeof phone !== "string") {
    return "";
  }

  let digits =
    phone.replace(/[^0-9]/g, "");

  if (
    digits.startsWith("00") &&
    digits.length > 2
  ) {
    digits =
      digits.substring(2);
  }

  if (
    digits.length === 10 &&
    digits.startsWith("3")
  ) {
    digits =
      `39${digits}`;
  }

  return digits;
}

function customerIdentity(data) {
  const normalizedPhone =
    normalizePhone(
        data.normalizedPhone ||
        data.telefono,
    );

  const normalizedEmail =
    normalizeEmail(
        data.normalizedEmail ||
        data.email,
    );

  const source =
    normalizedPhone.length > 0 ?
      `phone:${normalizedPhone}` :
      `email:${normalizedEmail}`;

  if (
    normalizedPhone.length === 0 &&
    normalizedEmail.length === 0
  ) {
    return null;
  }

  const profileId =
    crypto
        .createHash("sha256")
        .update(source)
        .digest("hex");

  return {
    profileId,
    normalizedPhone,
    normalizedEmail,
  };
}

function bookingDetails(data) {
  const guests =
    Number.isInteger(data.guests) ?
      data.guests :
      Number(data.guests || 0);

  return {
    name:
      customerName(data),

    guests,

    guestsText:
      guestsLabel(guests),

    date:
      formatDate(data.dateKey),

    time:
      typeof data.time === "string" ?
        data.time :
        "",

    service:
      serviceLabel(data.service),
  };
}

function safeEventId(eventId) {
  return crypto
      .createHash("sha256")
      .update(String(eventId || ""))
      .digest("hex");
}

// ============================================================
// NOTIFICA PUSH AMMINISTRATORE
// ============================================================

async function getNotificationTokens() {
  const [deviceSnapshot, adminSnapshot] = await Promise.all([
    db.collection(NOTIFICATION_DEVICES_COLLECTION).get(),
    db.collection(ADMINS_COLLECTION).get(),
  ]);

  const tokens = new Set();

  for (const snapshot of [deviceSnapshot, adminSnapshot]) {
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
  }

  return Array.from(tokens);
}

function buildNotification(data) {
  const details =
    bookingDetails(data);

  const active =
    data.status === "booked" ||
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
      active ?
        "Nuova prenotazione" :
        "Nuova richiesta da confermare",

    body:
      parts.join(" · "),
  };
}

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

        await snapshot.ref.set(
            {
              adminNotificationRead:
                false,

              adminNotificationCreatedAt:
                FieldValue.serverTimestamp(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge:
                true,
            },
        );

        const tokens =
          await getNotificationTokens();

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
// ARCHIVIO CLIENTI PROTETTO
// ============================================================

async function syncCustomerProfile(
    snapshot,
    bookingId,
) {
  const data =
    snapshot.data();

  if (
    !data ||
    data.source !== "customer"
  ) {
    return null;
  }

  const identity =
    customerIdentity(data);

  if (!identity) {
    logger.warn(
        "Impossibile identificare il cliente.",
        {
          bookingId,
        },
    );

    return null;
  }

  const profileReference =
    db
        .collection(
            CUSTOMER_PROFILES_COLLECTION,
        )
        .doc(
            identity.profileId,
        );

  let noShowCount = 0;

  await db.runTransaction(
      async (transaction) => {
        const profileSnapshot =
          await transaction.get(
              profileReference,
          );

        const profile =
          profileSnapshot.exists ?
            profileSnapshot.data() :
            null;

        noShowCount =
          Number(
              profile?.noShowCount || 0,
          );

        const profileData = {
          nome:
            typeof data.nome === "string" ?
              data.nome.trim() :
              "",

          cognome:
            typeof data.cognome === "string" ?
              data.cognome.trim() :
              "",

          email:
            typeof data.email === "string" ?
              data.email.trim() :
              "",

          normalizedEmail:
            identity.normalizedEmail,

          telefono:
            typeof data.telefono === "string" ?
              data.telefono.trim() :
              "",

          normalizedPhone:
            identity.normalizedPhone,

          lastBookingId:
            bookingId,

          lastBookingAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        };

        if (!profileSnapshot.exists) {
          profileData.noShowCount = 0;
          profileData.createdAt =
            FieldValue.serverTimestamp();
        }

        if (
          data.marketingEmailConsent === true
        ) {
          profileData.marketingEmailConsent =
            true;

          profileData.marketingEmailConsentAt =
            FieldValue.serverTimestamp();

          profileData.marketingEmailConsentSource =
            data.marketingConsentSource ||
            "customer_booking";

          profileData.marketingConsentVersion =
            data.marketingConsentVersion ||
            "1.0";
        }

        if (
          data.marketingWhatsappConsent === true
        ) {
          profileData.marketingWhatsappConsent =
            true;

          profileData.marketingWhatsappConsentAt =
            FieldValue.serverTimestamp();

          profileData.marketingWhatsappConsentSource =
            data.marketingConsentSource ||
            "customer_booking";

          profileData.marketingConsentVersion =
            data.marketingConsentVersion ||
            "1.0";
        }
        if (
          data.marketingEmailConsent === true ||
          data.marketingWhatsappConsent === true
        ) {
          profileData.marketingLastConsentAt =
            FieldValue.serverTimestamp();

          profileData.marketingConsentSource =
            data.marketingConsentSource ||
            "customer_booking";

          if (
            !profile ||
            !profile.marketingFirstConsentAt
          ) {
            profileData.marketingFirstConsentAt =
              FieldValue.serverTimestamp();
          }
        }

        transaction.set(
            profileReference,
            profileData,
            {
              merge: true,
            },
        );

        transaction.set(
            snapshot.ref,
            {
              customerProfileId:
                identity.profileId,

              normalizedPhone:
                identity.normalizedPhone,

              normalizedEmail:
                identity.normalizedEmail,

              customerNoShowCount:
                noShowCount,

              customerProfileSyncedAt:
                FieldValue.serverTimestamp(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
        );
      },
  );

  return {
    profileId:
      identity.profileId,

    noShowCount,
  };
}

// ============================================================
// REGISTRA O CORREGGE UN NO-SHOW
// ============================================================

async function updateNoShowProfile(
    beforeSnapshot,
    afterSnapshot,
    bookingId,
) {
  const before =
    beforeSnapshot.data();

  const after =
    afterSnapshot.data();

  if (
    !before ||
    !after ||
    after.source !== "customer"
  ) {
    return;
  }

  const oldStatus =
    before.status;

  const newStatus =
    after.status;

  const becameNoShow =
    oldStatus !== "no_show" &&
    newStatus === "no_show";

  const removedNoShow =
    oldStatus === "no_show" &&
    newStatus !== "no_show";

  if (
    !becameNoShow &&
    !removedNoShow
  ) {
    return;
  }

  const identity =
    customerIdentity(after);

  if (!identity) {
    logger.warn(
        "No-show senza identificatore cliente.",
        {
          bookingId,
        },
    );

    return;
  }

  const profileReference =
    db
        .collection(
            CUSTOMER_PROFILES_COLLECTION,
        )
        .doc(
            identity.profileId,
        );

  await db.runTransaction(
      async (transaction) => {
        const bookingSnapshot =
          await transaction.get(
              afterSnapshot.ref,
          );

        const profileSnapshot =
          await transaction.get(
              profileReference,
          );

        if (!bookingSnapshot.exists) {
          return;
        }

        const currentBooking =
          bookingSnapshot.data();

        if (!currentBooking) {
          return;
        }

        const alreadyRecorded =
          currentBooking.noShowRecorded === true;

        let currentCount =
          Number(
              profileSnapshot.data()
                  ?.noShowCount || 0,
          );

        if (
          becameNoShow &&
          !alreadyRecorded
        ) {
          currentCount += 1;

          transaction.set(
              afterSnapshot.ref,
              {
                noShowRecorded:
                  true,

                customerNoShowCount:
                  currentCount,

                noShowRecordedAt:
                  FieldValue.serverTimestamp(),

                updatedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge: true,
              },
          );
        } else if (
          removedNoShow &&
          alreadyRecorded
        ) {
          currentCount =
            Math.max(
                0,
                currentCount - 1,
            );

          transaction.set(
              afterSnapshot.ref,
              {
                noShowRecorded:
                  false,

                customerNoShowCount:
                  currentCount,

                noShowCorrectionAt:
                  FieldValue.serverTimestamp(),

                updatedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge: true,
              },
          );
        } else {
          return;
        }

        transaction.set(
            profileReference,
            {
              nome:
                typeof after.nome === "string" ?
                  after.nome.trim() :
                  "",

              cognome:
                typeof after.cognome === "string" ?
                  after.cognome.trim() :
                  "",

              email:
                typeof after.email === "string" ?
                  after.email.trim() :
                  "",

              normalizedEmail:
                identity.normalizedEmail,

              telefono:
                typeof after.telefono === "string" ?
                  after.telefono.trim() :
                  "",

              normalizedPhone:
                identity.normalizedPhone,

              noShowCount:
                currentCount,

              lastNoShowBookingId:
                becameNoShow ?
                  bookingId :
                  FieldValue.delete(),

              lastNoShowAt:
                becameNoShow ?
                  FieldValue.serverTimestamp() :
                  FieldValue.delete(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
        );
      },
  );

  logger.info(
      "Profilo no-show aggiornato.",
      {
        bookingId,
        becameNoShow,
        removedNoShow,
      },
  );
}

// ============================================================
// CONFIGURAZIONE EMAIL
// ============================================================

const EMAIL_TYPES = {
  received: {
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

  restored: {
    subject:
      "Prenotazione nuovamente attiva – Le Capase",

    title:
      "Prenotazione nuovamente attiva",

    opening:
      "la tua prenotazione presso Le Capase è stata " +
      "nuovamente attivata.",

    notice:
      "Il tuo tavolo è stato nuovamente riservato.",

    warning:
      "",

    closing:
      "Ti aspettiamo!",
  },

  rejected: {
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

EMAIL_TYPES.reminder = {
  subject:
    "Promemoria prenotazione - Le Capase",

  title:
    "Promemoria prenotazione",

  opening:
    "mancano circa 90 minuti alla tua prenotazione presso Le Capase.",

  notice:
    "Ti abbiamo inviato anche un messaggio WhatsApp per riconfermare la tua presenza.",

  warning:
    "Per confermare oppure annullare, utilizza i pulsanti presenti nel messaggio WhatsApp.",

  closing:
    "Ti aspettiamo!",
};

// ============================================================
// BLOCCO CONTRO EMAIL DUPLICATE
//
// Ogni evento Firestore possiede un ID univoco.
// Lo stesso evento non può inviare due volte la stessa email.
// ============================================================

async function claimEmailEvent({
  eventId,
  bookingId,
  type,
  email,
}) {
  const eventReference =
    db
        .collection(
            EMAIL_EVENTS_COLLECTION,
        )
        .doc(
            safeEventId(eventId),
        );

  return db.runTransaction(
      async (transaction) => {
        const eventSnapshot =
          await transaction.get(
              eventReference,
          );

        if (eventSnapshot.exists) {
          const eventData =
            eventSnapshot.data();

          if (
            eventData?.status === "sent" ||
            eventData?.status === "processing"
          ) {
            return false;
          }
        }

        transaction.set(
            eventReference,
            {
              bookingId,
              type,
              email,
              status:
                "processing",

              processingAt:
                FieldValue.serverTimestamp(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
        );

        return true;
      },
  );
}

async function completeEmailEvent({
  eventId,
  messageId,
}) {
  await db
      .collection(
          EMAIL_EVENTS_COLLECTION,
      )
      .doc(
          safeEventId(eventId),
      )
      .set(
          {
            status:
              "sent",

            messageId:
              messageId || null,

            sentAt:
              FieldValue.serverTimestamp(),

            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
      );
}

async function failEmailEvent({
  eventId,
  error,
}) {
  await db
      .collection(
          EMAIL_EVENTS_COLLECTION,
      )
      .doc(
          safeEventId(eventId),
      )
      .set(
          {
            status:
              "failed",

            error:
              String(error).slice(
                  0,
                  500,
              ),

            failedAt:
              FieldValue.serverTimestamp(),

            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
      );
}

// ============================================================
// CONTENUTO EMAIL
// ============================================================

function buildEmail(
    data,
    type,
) {
  const config =
    EMAIL_TYPES[type];

  const details =
    bookingDetails(data);

  const cancellationReason =
    typeof data.cancellationReason === "string" ?
      data.cancellationReason.trim() :
      "";

  const notice =
    (
      (type === "cancelled" || type === "rejected") &&
      cancellationReason.length > 0
    ) ?
      `Motivazione: ${cancellationReason}` :
      config.notice;

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
    notice,
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
        ${escapeHtml(notice)}
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
// WHATSAPP 360DIALOG - PARTE 1
// ============================================================

const WHATSAPP_TEMPLATES = Object.freeze({
  received:
    "le_capase_richiesta_ricevuta",

  confirmed:
    "le_capase_prenotazione_confermata",

  restored:
    "le_capase_prenotazione_confermata",

  rejected:
    "le_capase_richiesta_non_accettata",

  cancelled:
    "le_capase_prenotazione_annullata",
});

function whatsappTextParameter(value) {
  return {
    type: "text",
    text: String(value ?? ""),
  };
}

function whatsappBookingParameters(data) {
  const details =
    bookingDetails(data);

  return [
    details.name,
    details.date,
    details.time,
    String(details.guests),
  ];
}

async function claimWhatsappEvent({
  eventId,
  bookingId,
  type,
  phone,
}) {
  const ref =
    db
        .collection(
            WHATSAPP_EVENTS_COLLECTION,
        )
        .doc(
            safeEventId(eventId),
        );

  const claimed =
    await db.runTransaction(
        async (transaction) => {
          const existing =
            await transaction.get(ref);

          if (existing.exists) {
            return false;
          }

          transaction.set(
              ref,
              {
                eventId:
                  String(eventId),

                bookingId,

                type,

                phone,

                status:
                  "sending",

                createdAt:
                  FieldValue.serverTimestamp(),

                updatedAt:
                  FieldValue.serverTimestamp(),
              },
          );

          return true;
        },
    );

  return {
    claimed,
    ref,
  };
}

async function send360DialogTemplate({
  phone,
  templateName,
  bodyParameters,
}) {
  const response =
    await fetch(
        "https://waba-v2.360dialog.io/messages",
        {
          method:
            "POST",

          headers: {
            "Content-Type":
              "application/json",

            "D360-API-KEY":
              dialog360ApiKey.value(),
          },

          body:
            JSON.stringify({
              messaging_product:
                "whatsapp",

              recipient_type:
                "individual",

              to:
                phone,

              type:
                "template",

              template: {
                name:
                  templateName,

                language: {
                  code:
                    "it",
                },

                components: [
                  {
                    type:
                      "body",

                    parameters:
                      bodyParameters.map(
                          whatsappTextParameter,
                      ),
                  },
                ],
              },
            }),
        },
    );

  const rawBody =
    await response.text();

  let parsedBody =
    null;

  if (rawBody.length > 0) {
    try {
      parsedBody =
        JSON.parse(rawBody);
    } catch (_) {
      parsedBody =
        null;
    }
  }

  if (!response.ok) {
    throw new Error(
        `360dialog HTTP ${response.status}: ` +
        rawBody.substring(0, 500),
    );
  }

  return {
    messageId:
      parsedBody?.messages?.[0]?.id ||
      null,
  };
}

async function sendBookingWhatsapp({
  snapshot,
  bookingId,
  type,
  eventId,
}) {
  const data =
    snapshot.data();

  const templateName =
    WHATSAPP_TEMPLATES[type];

  if (
    !data ||
    data.source !== "customer" ||
    data.bookingWhatsappConsent !== true ||
    !templateName
  ) {
    return false;
  }

  const phone =
    normalizePhone(
        data.normalizedPhone ||
        data.telefono,
    );

  if (phone.length === 0) {
    return false;
  }

  const claim =
    await claimWhatsappEvent({
      eventId,
      bookingId,
      type,
      phone,
    });

  if (!claim.claimed) {
    return false;
  }

  try {
    const result =
      await send360DialogTemplate({
        phone,

        templateName,

        bodyParameters:
          whatsappBookingParameters(
              data,
          ),
      });

    await claim.ref.set(
        {
          status:
            "sent",

          messageId:
            result.messageId,

          sentAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge:
            true,
        },
    );

    const updateData = {
      lastCustomerWhatsappType:
        type,

      lastCustomerWhatsappSentAt:
        FieldValue.serverTimestamp(),

      lastCustomerWhatsappMessageId:
        result.messageId,

      updatedAt:
        FieldValue.serverTimestamp(),
    };

    if (type === "received") {
      updateData.requestReceivedWhatsappSent =
        true;
    }

    if (
      type === "confirmed" ||
      type === "restored"
    ) {
      updateData.confirmationWhatsappSent =
        true;
    }

    if (type === "cancelled") {
      updateData.cancellationWhatsappSent =
        true;
    }

    if (type === "rejected") {
      updateData.rejectionWhatsappSent =
        true;
    }

    await snapshot.ref.set(
        updateData,
        {
          merge:
            true,
        },
    );

    logger.info(
        "WhatsApp prenotazione inviato.",
        {
          bookingId,
          type,
        },
    );

    return true;
  } catch (error) {
    await claim.ref
        .delete()
        .catch(() => {});

    logger.error(
        "Invio WhatsApp prenotazione fallito.",
        {
          bookingId,
          type,
          error,
        },
    );

    return false;
  }
}
// ============================================================
// INVIO EMAIL
// ============================================================

async function sendBookingEmail({
  snapshot,
  bookingId,
  type,
  eventId,
}) {
  const data =
    snapshot.data();

  const config =
    EMAIL_TYPES[type];

  if (
    !data ||
    !config ||
    data.source !== "customer"
  ) {
    return;
  }

  await sendBookingWhatsapp({
    snapshot,
    bookingId,
    type,
    eventId: `${eventId}:whatsapp`,
  });

  const email =
    typeof data.email === "string" ?
      data.email.trim() :
      "";

  if (email.length === 0) {
    return;
  }

  const claimed =
    await claimEmailEvent({
      eventId,
      bookingId,
      type,
      email,
    });

  if (!claimed) {
    return;
  }

  const sender =
    gmailUser.value();

  const content =
    buildEmail(
        data,
        type,
    );

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

    await completeEmailEvent({
      eventId,
      messageId:
        result.messageId,
    });

    const updateData = {
      lastCustomerEmailType:
        type,

      lastCustomerEmailSentAt:
        FieldValue.serverTimestamp(),

      lastCustomerEmailMessageId:
        result.messageId || null,

      updatedAt:
        FieldValue.serverTimestamp(),
    };

    if (type === "received") {
      updateData.requestReceivedEmailSent =
        true;
    }

    if (
      type === "confirmed" ||
      type === "restored"
    ) {
      updateData.confirmationEmailSent =
        true;
    }

    if (type === "cancelled") {
      updateData.cancellationEmailSent =
        true;
    }

    if (type === "rejected") {
      updateData.rejectionEmailSent =
        true;
    }

    await snapshot.ref.set(
        updateData,
        {
          merge: true,
        },
    );

    logger.info(
        "Email prenotazione inviata.",
        {
          bookingId,
          type,
        },
    );
  } catch (error) {
    await failEmailEvent({
      eventId,
      error,
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
// CREAZIONE PRENOTAZIONE
//
// BOOKED / CONFIRMED:
// email conferma.
//
// PENDING:
// email presa in carico.
//
// Inoltre crea/aggiorna il profilo cliente.
// ============================================================

exports.onCustomerBookingCreated =
  onDocumentCreated(
      {
        document:
          `${BOOKINGS_COLLECTION}/{bookingId}`,

        secrets: [
          gmailUser,
          gmailAppPassword,
          dialog360ApiKey,
        ],
      },
      async (event) => {
        const snapshot =
          event.data;

        if (!snapshot) {
          return;
        }

        const bookingId =
          event.params.bookingId;

        const data =
          snapshot.data();

        await syncCustomerProfile(
            snapshot,
            bookingId,
        );

        if (
          data.status === "booked" ||
          data.status === "confirmed"
        ) {
          await sendBookingEmail({
            snapshot,
            bookingId,
            type:
              "confirmed",

            eventId:
              `${event.id}:confirmed`,
          });

          return;
        }

        if (data.status === "pending") {
          await sendBookingEmail({
            snapshot,
            bookingId,
            type:
              "received",

            eventId:
              `${event.id}:received`,
          });
        }
      },
  );

// ============================================================
// CAMBIO STATO DAL GESTIONALE
// ============================================================

exports.onCustomerBookingStatusChanged =
  onDocumentUpdated(
      {
        document:
          `${BOOKINGS_COLLECTION}/{bookingId}`,

        secrets: [
          gmailUser,
          gmailAppPassword,
          dialog360ApiKey,
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

        const beforeData =
          before.data();

        const afterData =
          after.data();

        const oldStatus =
          beforeData.status;

        const newStatus =
          afterData.status;

        if (oldStatus === newStatus) {
          return;
        }

        const bookingId =
          event.params.bookingId;

        await updateNoShowProfile(
            before,
            after,
            bookingId,
        );

        // Nessuna email per No-show.
        if (newStatus === "no_show") {
          return;
        }

        // Da annullata/no-show/rifiutata
        // torna attiva.
        if (
          (
            oldStatus === "cancelled" ||
            oldStatus === "no_show" ||
            oldStatus === "rejected"
          ) &&
          (
            newStatus === "booked" ||
            newStatus === "confirmed"
          )
        ) {
          await sendBookingEmail({
            snapshot:
              after,

            bookingId,

            type:
              "restored",

            eventId:
              `${event.id}:restored`,
          });

          return;
        }

        // Da in attesa a prenotata/confermata.
        if (
          newStatus === "booked" ||
          newStatus === "confirmed"
        ) {
          await sendBookingEmail({
            snapshot:
              after,

            bookingId,

            type:
              "confirmed",

            eventId:
              `${event.id}:confirmed`,
          });

          return;
        }

        // Una richiesta in attesa viene annullata:
        // email di richiesta non accettata.
        if (
          oldStatus === "pending" &&
          newStatus === "cancelled"
        ) {
          await sendBookingEmail({
            snapshot:
              after,

            bookingId,

            type:
              "rejected",

            eventId:
              `${event.id}:rejected`,
          });

          return;
        }

        // Una prenotazione attiva viene annullata.
        if (newStatus === "cancelled") {
          await sendBookingEmail({
            snapshot:
              after,

            bookingId,

            type:
              "cancelled",

            eventId:
              `${event.id}:cancelled`,
          });
        }
      },
  );

// ============================================================
// CAMPAGNE MARKETING - SOLO AMMINISTRATORI
// ============================================================

async function marketingUserIsAdmin(uid) {
  if (!uid) {
    return false;
  }

  const adminSnapshot =
    await db.collection("admins").doc(uid).get();

  if (
    adminSnapshot.exists &&
    adminSnapshot.data()?.active !== false
  ) {
    return true;
  }

  const staffSnapshot =
    await db.collection("staff_users").doc(uid).get();

  if (!staffSnapshot.exists) {
    return false;
  }

  const staffData = staffSnapshot.data();

  return staffData &&
    staffData.active === true &&
    staffData.role === "admin";
}

const MARKETING_WHATSAPP_TEXT_TEMPLATE =
  "le_capase_novita_marketing";

const MARKETING_WHATSAPP_IMAGE_TEMPLATE =
  "le_capase_novita_marketing_image";

const MARKETING_WHATSAPP_IMAGE_URL =
  "https://lecapase-booking-3af33.web.app/" +
  "images/capa-marketing-template.png";

function marketingFirstName(data) {
  const value =
    (typeof data.nome === "string" && data.nome.trim()) ||
    (typeof data.firstName === "string" && data.firstName.trim()) ||
    (typeof data.name === "string" && data.name.trim()) ||
    "";

  return value.length > 0 ? value : "Cliente";
}

function marketingEmail(data) {
  const value =
    (typeof data.email === "string" && data.email.trim()) ||
    (typeof data.normalizedEmail === "string" &&
      data.normalizedEmail.trim()) ||
    "";

  return value;
}

function marketingPhone(data) {
  return normalizePhone(
      data.normalizedPhone ||
      data.telefono ||
      data.phone ||
      "",
  );
}

function marketingHtmlEscape(value) {
  return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
}

async function sendMarketingCampaignWhatsapp({
  phone,
  templateName,
  firstName,
  message,
  imageUrl,
}) {
  const safeFirstName =
    String(firstName ?? "")
        .replace(/\s+/g, " ")
        .trim();

  const safeMessage =
    String(message ?? "")
        .replace(/\s+/g, " ")
        .trim();

  const components = [];

  if (
    typeof imageUrl === "string" &&
    imageUrl.trim().length > 0
  ) {
    components.push({
      type: "header",
      parameters: [
        {
          type: "image",
          image: {
            link: imageUrl.trim(),
          },
        },
      ],
    });
  }

  components.push({
    type: "body",
    parameters: [
      whatsappTextParameter(safeFirstName),
      whatsappTextParameter(safeMessage),
    ],
  });

  const response =
    await fetch(
        "https://waba-v2.360dialog.io/messages",
        {
          method: "POST",

          headers: {
            "Content-Type": "application/json",

            "D360-API-KEY":
              dialog360ApiKey.value(),
          },

          body:
            JSON.stringify({
              messaging_product: "whatsapp",
              recipient_type: "individual",
              to: phone,
              type: "template",

              template: {
                name: templateName,

                language: {
                  code: "it",
                },

                components,
              },
            }),
        },
    );

  const rawBody =
    await response.text();

  let parsedBody =
    null;

  if (rawBody.length > 0) {
    try {
      parsedBody =
        JSON.parse(rawBody);
    } catch (_) {
      parsedBody =
        null;
    }
  }

  if (!response.ok) {
    throw new Error(
        `360dialog HTTP ${response.status}: ` +
        rawBody.substring(0, 500),
    );
  }

  return {
    messageId:
      parsedBody?.messages?.[0]?.id ||
      null,

    response:
      parsedBody,
  };
}

exports.sendMarketingCampaign =
  onCall(
      {
        region: "europe-west1",
        timeoutSeconds: 300,

        secrets: [
          gmailUser,
          gmailAppPassword,
          dialog360ApiKey,
        ],
      },
      async (request) => {
        const uid =
          request.auth &&
          request.auth.uid;

        if (!uid) {
          throw new HttpsError(
              "unauthenticated",
              "Devi effettuare l'accesso.",
          );
        }

        if (!await marketingUserIsAdmin(uid)) {
          throw new HttpsError(
              "permission-denied",
              "Solo un amministratore può inviare campagne.",
          );
        }

        const data =
          request.data || {};

        const campaignName =
          typeof data.campaignName === "string" ?
            data.campaignName.trim() :
            "";

        const message =
          typeof data.message === "string" ?
            data.message.trim() :
            "";

        let channel =
          typeof data.channel === "string" ?
            data.channel.trim() :
            "";

        // Compatibilità con la vecchia UI.
        if (channel === "whatsapp") {
          channel = "whatsapp_image";
        }

        let campaignImageUrl =
          typeof data.imageUrl === "string" ?
            data.imageUrl.trim() :
            "";

        const imageBase64 =
          typeof data.imageBase64 === "string" ?
            data.imageBase64.trim() :
            "";

        const imageFileName =
          typeof data.imageFileName === "string" ?
            data.imageFileName.trim() :
            "";

        const imageContentType =
          typeof data.imageContentType === "string" ?
            data.imageContentType.trim().toLowerCase() :
            "";

        if (
          campaignImageUrl.length > 0 &&
          !campaignImageUrl.startsWith("https://")
        ) {
          throw new HttpsError(
              "invalid-argument",
              "URL immagine campagna non valido.",
          );
        }

        if (imageBase64.length > 0) {
          const allowedImageTypes =
            new Set([
              "image/jpeg",
              "image/png",
              "image/webp",
            ]);

          if (!allowedImageTypes.has(imageContentType)) {
            throw new HttpsError(
                "invalid-argument",
                "Formato immagine non supportato.",
            );
          }

          if (imageBase64.length > 7 * 1024 * 1024) {
            throw new HttpsError(
                "invalid-argument",
                "Immagine troppo grande.",
            );
          }

          const imageBuffer =
            Buffer.from(imageBase64, "base64");

          if (
            imageBuffer.length === 0 ||
            imageBuffer.length > 5 * 1024 * 1024
          ) {
            throw new HttpsError(
                "invalid-argument",
                "Immagine non valida o superiore a 5 MB.",
            );
          }

          const safeImageFileName =
            imageFileName
                .replace(/[^A-Za-z0-9._-]/g, "_")
                .slice(-120) ||
            "campaign.jpg";

          const objectPath =
            "marketing_campaigns/" +
            Date.now() +
            "_" +
            crypto.randomUUID() +
            "_" +
            safeImageFileName;

          try {
            const bucket =
              getStorage().bucket(
                  "lecapase-booking-3af33.firebasestorage.app",
              );

            const file =
              bucket.file(objectPath);

            await file.save(
                imageBuffer,
                {
                  resumable: false,
                  metadata: {
                    contentType:
                      imageContentType,
                    cacheControl:
                      "public,max-age=3600",
                  },
                },
            );

            campaignImageUrl =
              await getDownloadURL(file);
          } catch (error) {
            logger.error(
                "Upload immagine campagna fallito.",
                {
                  error: String(error),
                },
            );

            throw new HttpsError(
                "internal",
                "Caricamento foto campagna non riuscito.",
            );
          }
        }
        const customerIds =
          Array.isArray(data.customerIds) ?
            [
              ...new Set(
                  data.customerIds
                      .filter((value) =>
                        typeof value === "string" &&
                        value.trim().length > 0,
                      )
                      .map((value) => value.trim()),
              ),
            ] :
            [];

        if (campaignName.length < 2) {
          throw new HttpsError(
              "invalid-argument",
              "Inserisci il nome della campagna.",
          );
        }

        if (message.length < 2) {
          throw new HttpsError(
              "invalid-argument",
              "Inserisci il messaggio della campagna.",
          );
        }

        const allowedChannels =
          new Set([
            "email",
            "whatsapp_text",
            "whatsapp_image",
            "both",
          ]);

        if (!allowedChannels.has(channel)) {
          throw new HttpsError(
              "invalid-argument",
              "Canale campagna non valido.",
          );
        }

        if (customerIds.length < 1) {
          throw new HttpsError(
              "invalid-argument",
              "Seleziona almeno un destinatario.",
          );
        }

        if (customerIds.length > 50) {
          throw new HttpsError(
              "invalid-argument",
              "Sono consentiti al massimo 50 destinatari.",
          );
        }

        const wantsEmail =
          channel === "email" ||
          channel === "both";

        const wantsWhatsapp =
          channel === "whatsapp_text" ||
          channel === "whatsapp_image" ||
          channel === "both";

        const whatsappImage =
          channel === "whatsapp_image" ||
          channel === "both";

        const effectiveWhatsappImageUrl =
          whatsappImage ?
            (
              campaignImageUrl.length > 0 ?
                campaignImageUrl :
                MARKETING_WHATSAPP_IMAGE_URL
            ) :
            null;

        let transporter =
          null;

        let sender =
          "";

        if (wantsEmail) {
          sender =
            gmailUser.value();

          transporter =
            nodemailer.createTransport({
              service: "gmail",

              auth: {
                user: sender,
                pass: gmailAppPassword.value(),
              },
            });
        }

        let emailSent = 0;
        let emailSkipped = 0;
        let emailFailed = 0;

        let whatsappSent = 0;
        let whatsappSkipped = 0;
        let whatsappFailed = 0;

        const recipients = [];

        for (const customerId of customerIds) {
          const recipient = {
            customerId,
          };

          const profileSnapshot =
            await db
                .collection("customer_profiles")
                .doc(customerId)
                .get();

          if (!profileSnapshot.exists) {
            recipient.status =
              "not_found";

            if (wantsEmail) {
              emailSkipped += 1;
              recipient.emailStatus =
                "skipped";
            }

            if (wantsWhatsapp) {
              whatsappSkipped += 1;
              recipient.whatsappStatus =
                "skipped";
            }

            recipients.push(recipient);
            continue;
          }

          const customer =
            profileSnapshot.data() || {};

          const firstName =
            marketingFirstName(customer);

          const email =
            marketingEmail(customer);

          const phone =
            marketingPhone(customer);

          recipient.name =
            firstName;

          recipient.email =
            email || null;

          recipient.phone =
            phone || null;

          // --------------------------------
          // EMAIL
          // --------------------------------

          if (wantsEmail) {
            if (
              customer.marketingEmailConsent !== true ||
              !email ||
              !email.includes("@")
            ) {
              emailSkipped += 1;

              recipient.emailStatus =
                "skipped";
            } else {
              try {
                const textBody =
                  `Ciao ${firstName},\n\n` +
                  `${message}\n\n` +
                  "Le Capase";

                const safeName =
                  marketingHtmlEscape(firstName);

                const safeMessage =
                  marketingHtmlEscape(message)
                      .replace(/\n/g, "<br>");

                const safeImageUrl =
                  marketingHtmlEscape(campaignImageUrl);

                const imageHtml =
                  campaignImageUrl.length > 0 ?
                    `<p><img src="${safeImageUrl}" ` +
                    `alt="${marketingHtmlEscape(campaignName)}" ` +
                    `style="max-width:100%;height:auto;border-radius:12px;">` +
                    `</p>` :
                    "";

                const htmlBody =
                  `<p>Ciao ${safeName},</p>` +
                  imageHtml +
                  `<p>${safeMessage}</p>` +
                  "<p><strong>Le Capase</strong></p>";

                const result =
                  await transporter.sendMail({
                    from:
                      `"Le Capase" <${sender}>`,

                    replyTo:
                      sender,

                    to:
                      email,

                    subject:
                      campaignName,

                    text:
                      textBody,

                    html:
                      htmlBody,
                  });

                emailSent += 1;

                recipient.emailStatus =
                  "sent";

                recipient.emailMessageId =
                  result.messageId ||
                  null;
              } catch (error) {
                emailFailed += 1;

                recipient.emailStatus =
                  "failed";

                recipient.emailError =
                  String(
                      error?.message ||
                      error,
                  ).substring(0, 500);
              }
            }
          }

          // --------------------------------
          // WHATSAPP
          // --------------------------------

          if (wantsWhatsapp) {
            if (
              customer.marketingWhatsappConsent !== true ||
              phone.length === 0
            ) {
              whatsappSkipped += 1;

              recipient.whatsappStatus =
                "skipped";
            } else {
              try {
                const templateName =
                  whatsappImage ?
                    MARKETING_WHATSAPP_IMAGE_TEMPLATE :
                    MARKETING_WHATSAPP_TEXT_TEMPLATE;

                const result =
                  await sendMarketingCampaignWhatsapp({
                    phone,
                    templateName,
                    firstName,
                    message,

                    imageUrl:
                      effectiveWhatsappImageUrl,
                  });

                whatsappSent += 1;

                recipient.whatsappStatus =
                  "sent";

                recipient.whatsappMessageId =
                  result.messageId;
              } catch (error) {
                whatsappFailed += 1;

                recipient.whatsappStatus =
                  "failed";

                recipient.whatsappError =
                  String(
                      error?.message ||
                      error,
                  ).substring(0, 500);
              }
            }
          }

          recipients.push(recipient);
        }

        const campaignReference =
          db.collection("marketing_campaigns").doc();

        const sent =
          emailSent +
          whatsappSent;

        const skipped =
          emailSkipped +
          whatsappSkipped;

        const failed =
          emailFailed +
          whatsappFailed;

        await campaignReference.set({
          campaignName,
          message,
          channel,

          createdBy:
            uid,

          createdAt:
            FieldValue.serverTimestamp(),

          requestedRecipients:
            customerIds.length,

          sentRecipients:
            sent,

          skippedRecipients:
            skipped,

          failedRecipients:
            failed,

          emailSent,
          emailSkipped,
          emailFailed,

          whatsappSent,
          whatsappSkipped,
          whatsappFailed,

          whatsappTemplate:
            wantsWhatsapp ?
              (
                whatsappImage ?
                  MARKETING_WHATSAPP_IMAGE_TEMPLATE :
                  MARKETING_WHATSAPP_TEXT_TEMPLATE
              ) :
              null,

          whatsappImageUrl:
            effectiveWhatsappImageUrl,

          campaignImageUrl:
            campaignImageUrl.length > 0 ?
              campaignImageUrl :
              null,

          recipients,
        });

        logger.info(
            "Campagna marketing elaborata.",
            {
              campaignId:
                campaignReference.id,

              channel,
              requested:
                customerIds.length,

              emailSent,
              emailSkipped,
              emailFailed,

              whatsappSent,
              whatsappSkipped,
              whatsappFailed,
            },
        );

        return {
          success: true,

          campaignId:
            campaignReference.id,

          requested:
            customerIds.length,

          sent,
          skipped,
          failed,

          emailSent,
          emailSkipped,
          emailFailed,

          whatsappSent,
          whatsappSkipped,
          whatsappFailed,

          channel,
        };
      },
  );
const staffUserFunctions =
  require("./staff_users");

exports.onStaffUserInviteCreated =
  staffUserFunctions.onStaffUserInviteCreated;

exports.onStaffUserUpdated =
  staffUserFunctions.onStaffUserUpdated;


// ============================================================
// RICONFERMA 90 MINUTI - PARTE 2
// ============================================================

const RECONFIRMATION_TEMPLATE =
  "le_capase_richiesta_riconferma";

function romeMinuteKey(date) {
  const parts =
    new Intl.DateTimeFormat(
        "en-GB",
        {
          timeZone:
            "Europe/Rome",

          year:
            "numeric",

          month:
            "2-digit",

          day:
            "2-digit",

          hour:
            "2-digit",

          minute:
            "2-digit",

          hourCycle:
            "h23",
        },
    ).formatToParts(date);

  const values = {};

  for (const part of parts) {
    if (part.type !== "literal") {
      values[part.type] =
        part.value;
    }
  }

  return {
    dateKey:
      `${values.year}-${values.month}-${values.day}`,

    time:
      `${values.hour}:${values.minute}`,
  };
}

async function syncCurrentBusinessDate(now) {
  const current =
    romeMinuteKey(now);

  const reference =
    db
        .collection("_system")
        .doc("current_business_date");

  const snapshot =
    await reference.get();

  if (
    snapshot.exists &&
    snapshot.data()?.dateKey === current.dateKey
  ) {
    return;
  }

  await reference.set(
      {
        dateKey:
          current.dateKey,

        timeZone:
          "Europe/Rome",

        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge:
          true,
      },
  );

  logger.info(
      "Data operativa sincronizzata",
      {
        dateKey:
          current.dateKey,
      },
  );
}

function reminderMinuteKeys(now) {
  const keys =
    new Set();

  // Finestra di tolleranza:
  // 89, 90 e 91 minuti.
  //
  // Il blocco anti-duplicati impedisce
  // invii multipli.
  for (const minutes of [89, 90, 91]) {
    const target =
      new Date(
          now.getTime() +
          minutes * 60 * 1000,
      );

    const parts =
      romeMinuteKey(target);

    keys.add(
        `${parts.dateKey}|${parts.time}`,
    );
  }

  return keys;
}

async function sendReconfirmationWhatsapp({
  snapshot,
  bookingId,
  eventId,
}) {
  const data =
    snapshot.data();

  if (
    !data ||
    data.source !== "customer" ||
    data.bookingWhatsappConsent !== true
  ) {
    return false;
  }

  const phone =
    normalizePhone(
        data.normalizedPhone ||
        data.telefono,
    );

  if (phone.length === 0) {
    return false;
  }

  const details =
    bookingDetails(data);

  const claim =
    await claimWhatsappEvent({
      eventId,
      bookingId,
      type:
        "reconfirmation_reminder",
      phone,
    });

  if (!claim.claimed) {
    return false;
  }

  try {
    const body = {
      messaging_product:
        "whatsapp",

      recipient_type:
        "individual",

      to:
        phone,

      type:
        "template",

      template: {
        name:
          RECONFIRMATION_TEMPLATE,

        language: {
          code:
            "it",
        },

        components: [
          {
            type:
              "body",

            parameters: [
              whatsappTextParameter(
                  details.name,
              ),

              whatsappTextParameter(
                  details.time,
              ),

              whatsappTextParameter(
                  String(details.guests),
              ),
            ],
          },

          {
            type:
              "button",

            sub_type:
              "quick_reply",

            index:
              "0",

            parameters: [
              {
                type:
                  "payload",

                payload:
                  `confirm:${bookingId}`,
              },
            ],
          },

          {
            type:
              "button",

            sub_type:
              "quick_reply",

            index:
              "1",

            parameters: [
              {
                type:
                  "payload",

                payload:
                  `cancel:${bookingId}`,
              },
            ],
          },
        ],
      },
    };

    const response =
      await fetch(
          "https://waba-v2.360dialog.io/messages",
          {
            method:
              "POST",

            headers: {
              "Content-Type":
                "application/json",

              "D360-API-KEY":
                dialog360ApiKey.value(),
            },

            body:
              JSON.stringify(body),
          },
      );

    const raw =
      await response.text();

    let parsed =
      null;

    if (raw.length > 0) {
      try {
        parsed =
          JSON.parse(raw);
      } catch (_) {
        parsed =
          null;
      }
    }

    if (!response.ok) {
      throw new Error(
          `360dialog HTTP ${response.status}: ` +
          raw.substring(0, 500),
      );
    }

    const messageId =
      parsed?.messages?.[0]?.id ||
      null;

    await claim.ref.set(
        {
          status:
            "sent",

          messageId,

          sentAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge:
            true,
        },
    );

    await snapshot.ref.set(
        {
          reconfirmationWhatsappSent:
            true,

          reconfirmationWhatsappSentAt:
            FieldValue.serverTimestamp(),

          reconfirmationStatus:
            "pending",

          reconfirmationMessageId:
            messageId,

          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge:
            true,
        },
    );

    logger.info(
        "Richiesta riconferma WhatsApp inviata.",
        {
          bookingId,
        },
    );

    return true;
  } catch (error) {
    await claim.ref
        .delete()
        .catch(() => {});

    logger.error(
        "Invio richiesta riconferma WhatsApp fallito.",
        {
          bookingId,
          error,
        },
    );

    return false;
  }
}

async function processReconfirmationBooking(
    snapshot,
) {
  const data =
    snapshot.data();

  const bookingId =
    snapshot.id;

  if (
    !data ||
    data.source !== "customer"
  ) {
    return;
  }

  if (
    data.status !== "booked" &&
    data.status !== "confirmed"
  ) {
    return;
  }

  const stableEventId =
    `reconfirmation:${bookingId}:` +
    `${data.dateKey || ""}:` +
    `${data.time || ""}`;

  // EMAIL
  await sendBookingEmail({
    snapshot,
    bookingId,
    type:
      "reminder",

    eventId:
      `${stableEventId}:email`,
  });

  // WHATSAPP INTERATTIVO
  await sendReconfirmationWhatsapp({
    snapshot,
    bookingId,

    eventId:
      `${stableEventId}:whatsapp`,
  });

  await snapshot.ref.set(
      {
        reconfirmationReminderTriggered:
          true,

        reconfirmationReminderTriggeredAt:
          FieldValue.serverTimestamp(),

        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge:
          true,
      },
  );
}

exports.sendReconfirmationReminders =
  onSchedule(
      {
        schedule:
          "* * * * *",

        timeZone:
          "Europe/Rome",

        secrets: [
          gmailUser,
          gmailAppPassword,
          dialog360ApiKey,
        ],

        timeoutSeconds:
          120,
      },
      async () => {
        const now =
          new Date();

        await syncCurrentBusinessDate(now);

        const wantedKeys =
          reminderMinuteKeys(now);

        const wantedDates =
          new Set();

        for (const key of wantedKeys) {
          wantedDates.add(
              key.substring(0, 10),
          );
        }

        let checked =
          0;

        let matched =
          0;

        for (const dateKey of wantedDates) {
          const query =
            await db
                .collection(
                    BOOKINGS_COLLECTION,
                )
                .where(
                    "dateKey",
                    "==",
                    dateKey,
                )
                .get();

          for (const snapshot of query.docs) {
            checked++;

            const data =
              snapshot.data();

            const minuteKey =
              `${data.dateKey || ""}|` +
              `${data.time || ""}`;

            if (!wantedKeys.has(minuteKey)) {
              continue;
            }

            if (
              data.status !== "booked" &&
              data.status !== "confirmed"
            ) {
              continue;
            }

            matched++;

            await processReconfirmationBooking(
                snapshot,
            );
          }
        }

        logger.info(
            "Controllo riconferme completato.",
            {
              checked,
              matched,
            },
        );
      },
  );

// ============================================================
// WEBHOOK 360DIALOG
// ============================================================

function extractWhatsappMessages(body) {
  const messages =
    [];

  const entries =
    Array.isArray(body?.entry) ?
      body.entry :
      [];

  for (const entry of entries) {
    const changes =
      Array.isArray(entry?.changes) ?
        entry.changes :
        [];

    for (const change of changes) {
      const value =
        change?.value;

      const incoming =
        Array.isArray(value?.messages) ?
          value.messages :
          [];

      for (const message of incoming) {
        messages.push(message);
      }
    }
  }

  return messages;
}

function quickReplyPayload(message) {
  const buttonPayload =
    typeof message?.button?.payload === "string" ?
      message.button.payload :
      "";

  if (buttonPayload.length > 0) {
    return buttonPayload;
  }

  const interactiveId =
    typeof message
        ?.interactive
        ?.button_reply
        ?.id === "string" ?
      message.interactive.button_reply.id :
      "";

  return interactiveId;
}

async function processReconfirmationReply(
    message,
) {
  const payload =
    quickReplyPayload(message);

  if (
    !payload.startsWith("confirm:") &&
    !payload.startsWith("cancel:")
  ) {
    return;
  }

  const separator =
    payload.indexOf(":");

  const action =
    payload.substring(
        0,
        separator,
    );

  const bookingId =
    payload.substring(
        separator + 1,
    );

  if (bookingId.length === 0) {
    return;
  }

  const fromPhone =
    normalizePhone(
        String(message?.from || ""),
    );

  const ref =
    db
        .collection(
            BOOKINGS_COLLECTION,
        )
        .doc(
            bookingId,
        );

  await db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(ref);

        if (!snapshot.exists) {
          return;
        }

        const data =
          snapshot.data();

        const bookingPhone =
          normalizePhone(
              data.normalizedPhone ||
              data.telefono,
          );

        // La risposta deve arrivare
        // dallo stesso numero della prenotazione.
        if (
          fromPhone.length === 0 ||
          bookingPhone.length === 0 ||
          fromPhone !== bookingPhone
        ) {
          logger.warn(
              "Risposta WhatsApp ignorata: numero non corrispondente.",
              {
                bookingId,
              },
          );

          return;
        }

        if (
          data.status !== "booked" &&
          data.status !== "confirmed"
        ) {
          return;
        }

        if (action === "confirm") {
          transaction.set(
              ref,
              {
                reconfirmationStatus:
                  "confirmed",

                reconfirmed:
                  true,

                reconfirmedAt:
                  FieldValue.serverTimestamp(),

                reconfirmedVia:
                  "whatsapp",

                reconfirmationResultRead:
                  false,

                lastWhatsappReply:
                  "confirm",

                lastWhatsappReplyAt:
                  FieldValue.serverTimestamp(),

                updatedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge:
                  true,
              },
          );

          return;
        }

        if (action === "cancel") {
          const guests =
            Number.isInteger(data.guests) ?
              data.guests :
              Number(data.guests || 0);

          const dateKey =
            typeof data.dateKey === "string" ?
              data.dateKey :
              "";

          const service =
            typeof data.service === "string" ?
              data.service :
              "";

          if (
            dateKey.length > 0 &&
            service.length > 0 &&
            guests > 0
          ) {
            const counterRef =
              db
                  .collection(
                      "availability_counters",
                  )
                  .doc(
                      `${dateKey}_${service}`,
                  );

            const counterSnapshot =
              await transaction.get(
                  counterRef,
              );

            const currentGuests =
              counterSnapshot.exists ?
                Number(
                    counterSnapshot
                        .data()
                        ?.bookedGuests || 0,
                ) :
                0;

            const updatedGuests =
              Math.max(
                  0,
                  currentGuests - guests,
              );

            transaction.set(
                counterRef,
                {
                  dateKey,

                  service,

                  bookedGuests:
                    updatedGuests,

                  lastBookingId:
                    bookingId,

                  updatedAt:
                    FieldValue.serverTimestamp(),
                },
                {
                  merge:
                    true,
                },
            );
          }

          transaction.set(
              ref,
              {
                status:
                  "cancelled",

                reconfirmationStatus:
                  "cancelled",

                reconfirmed:
                  false,

                cancelledByCustomer:
                  true,

                cancelledAt:
                  FieldValue.serverTimestamp(),

                cancelledBy:
                  "customer_whatsapp",

                cancellationSource:
                  "whatsapp_reconfirmation",

                reconfirmationResultRead:
                  false,

                lastWhatsappReply:
                  "cancel",

                lastWhatsappReplyAt:
                  FieldValue.serverTimestamp(),

                updatedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge:
                  true,
              },
          );
        }
      },
  );

  logger.info(
      "Risposta riconferma WhatsApp elaborata.",
      {
        bookingId,
        action,
      },
  );
}

async function processMarketingWhatsappOptOut(message) {
  const rawText =
    message?.text?.body ||
    message?.text ||
    message?.button?.text ||
    message?.interactive?.button_reply?.title ||
    message?.interactive?.list_reply?.title ||
    "";

  const text = String(rawText).trim().toUpperCase();

  const isOptOut =
    /^(STOP|ANNULLA|DISISCRIVIMI|BASTA)$/.test(text);

  if (!isOptOut) return false;

  const phone = normalizePhone(
      message?.from ||
      message?.wa_id ||
      message?.waId ||
      "",
  );

  if (phone.length === 0) {
    logger.warn(
        "Richiesta STOP marketing senza numero WhatsApp.",
    );
    return true;
  }

  const profiles = await db
      .collection(CUSTOMER_PROFILES_COLLECTION)
      .where("normalizedPhone", "==", phone)
      .limit(20)
      .get();

  if (profiles.empty) {
    logger.warn(
        "Richiesta STOP marketing senza profilo cliente.",
        {phone},
    );
    return true;
  }

  const batch = db.batch();

  for (const document of profiles.docs) {
    batch.set(
        document.ref,
        {
          marketingEmailConsent: false,
          marketingWhatsappConsent: false,
          marketingOptOutAt: FieldValue.serverTimestamp(),
          marketingOptOutSource: "whatsapp_stop",
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  }

  await batch.commit();

  logger.info(
      "Consensi marketing revocati tramite WhatsApp.",
      {
        phone,
        profiles: profiles.size,
      },
  );

  return true;
}

function validDialog360WebhookToken(request) {
  const expectedToken =
    dialog360WebhookToken
        .value()
        .trim();

  const receivedToken =
    typeof request.get(
        "x-lecapase-webhook-token",
    ) === "string" ?
      request
          .get("x-lecapase-webhook-token")
          .trim() :
      "";

  const expectedBuffer =
    Buffer.from(expectedToken);

  const receivedBuffer =
    Buffer.from(receivedToken);

  if (
    expectedBuffer.length === 0 ||
    expectedBuffer.length !==
      receivedBuffer.length
  ) {
    return false;
  }

  return require("crypto")
      .timingSafeEqual(
          expectedBuffer,
          receivedBuffer,
      );
}
exports.dialog360Webhook =
  onRequest(
      {
        cors:
          false,

        timeoutSeconds:
          60,
        secrets: [
          dialog360WebhookToken,
        ],
      },
      async (request, response) => {
        if (request.method !== "POST") {
          response
              .status(200)
              .send("Le Capase 360dialog webhook");

          return;
        }

        if (!validDialog360WebhookToken(request)) {
          logger.warn(
              "Token webhook 360dialog non valido.",
          );

          response
              .status(401)
              .send("UNAUTHORIZED");

          return;
        }
        try {
          const messages =
            extractWhatsappMessages(
                request.body,
            );

          for (const message of messages) {
              const marketingOptOut =
                await processMarketingWhatsappOptOut(
                    message,
                );

              if (!marketingOptOut) {
                await processReconfirmationReply(
                    message,
                );
              }
            }

          response
              .status(200)
              .send("OK");
        } catch (error) {
          logger.error(
              "Errore webhook 360dialog.",
              {
                error,
              },
          );

          // Restituiamo errore per consentire
          // al provider di ritentare.
          response
              .status(500)
              .send("ERROR");
        }
      },
  );

// ============================================================
// FINE RICONFERMA 90 MINUTI - PARTE 2
// ============================================================

exports.listActiveStaffProfiles =
  staffUserFunctions.listActiveStaffProfiles;

exports.createStaffUser =
  staffUserFunctions.createStaffUser;

exports.resetStaffPassword =
  staffUserFunctions.resetStaffPassword;

exports.completeFirstStaffLogin =
  staffUserFunctions.completeFirstStaffLogin;

exports.notifyStaffLogin =
  staffUserFunctions.notifyStaffLogin;
exports.deleteStaffUser =
  staffUserFunctions.deleteStaffUser;

exports.getKitchenAgenda =
  staffUserFunctions.getKitchenAgenda;

exports.closeBookingService =
  staffUserFunctions.closeBookingService;
