const WEBHOOK_URL = 'https://davidvanwachem.app.n8n.cloud/webhook/get-agenda-page-details';

const MAX_RETRIES = 3;
const INITIAL_RETRY_DELAY = 5000;

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const generateEventId = () => {
    return 'evt_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
};

const fetchWithRetry = async (url, options, retries = MAX_RETRIES) => {
    for (let attempt = 0; attempt <= retries; attempt++) {
        try {
            const response = await fetch(url, options);

            if (response.ok) {
                return { ok: true, response };
            }

            if (response.status >= 500 && attempt < retries) {
                const delay = INITIAL_RETRY_DELAY * Math.pow(2, attempt);
                console.log(`[Webhook] Server error ${response.status}, retrying in ${delay / 1000}s (attempt ${attempt + 1}/${retries})`);
                await sleep(delay);
                continue;
            }

            return { ok: false, message: `HTTP ${response.status}`, response };
        } catch (error) {
            if (attempt < retries) {
                const delay = INITIAL_RETRY_DELAY * Math.pow(2, attempt);
                console.log(`[Webhook] Network error, retrying in ${delay / 1000}s (attempt ${attempt + 1}/${retries}):`, error.message);
                await sleep(delay);
                continue;
            }
            return { ok: false, message: error.message, error };
        }
    }
    return { ok: false, message: 'Max retries exceeded' };
};

export const sendWebhookData = async (eventType, data) => {
    const payload = {
        eventId: generateEventId(),
        eventType,
        timestamp: new Date().toISOString(),
        ...data
    };

    console.log(`[Webhook] Sending ${eventType} event:`, payload);

    const result = await fetchWithRetry(WEBHOOK_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload)
    });

    if (result.ok) {
        console.log(`[Webhook] Successfully sent ${eventType} event`);
    } else {
        console.error(`[Webhook] Failed to send ${eventType} event:`, result.message);
    }

    return result;
};

export const sendLoginEvent = async (phoneNumber, dossierId) => {
    return sendWebhookData('login', {
        phoneNumber,
        dossierId
    });
};

export const sendTenantDataEvent = async (personData) => {
    return sendWebhookData('tenant_data', {
        data: {
            personId: personData.personId,
            naam: personData.naam,
            email: personData.email,
            address: personData.address || personData.adres,
            postcode: personData.postcode,
            city: personData.city || personData.woonplaats,
            income: personData.income || personData.inkomen,
            workStatus: personData.workStatus,
            rol: personData.rol,
            phone: personData.phone || personData.telefoon
        }
    });
};

export const sendDocumentUploadEvent = async (personId, documentType, file) => {
    const formData = new FormData();

    formData.append('eventId', generateEventId());
    formData.append('eventType', 'document_upload');
    formData.append('timestamp', new Date().toISOString());
    formData.append('personId', personId);
    formData.append('documentType', documentType);
    formData.append('status', 'ontvangen');

    if (file && file instanceof File) {
        const ext = file.name.includes('.') ? '.' + file.name.split('.').pop() : '';
        const baseName = file.name.includes('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
        const newFileName = `${baseName}_${documentType}${ext}`;

        formData.append('file', file, newFileName);
        formData.append('fileName', newFileName);
        formData.append('originalFileName', file.name);
        formData.append('fileType', file.type);
        formData.append('fileSize', file.size.toString());
    }

    console.log(`[Webhook] Sending document_upload event via multipart:`, {
        personId,
        documentType,
        fileName: file?.name
    });

    const result = await fetchWithRetry(WEBHOOK_URL, {
        method: 'POST',
        body: formData
    });

    if (result.ok) {
        console.log(`[Webhook] Successfully sent document_upload event`);
    } else {
        console.error(`[Webhook] Failed to send document_upload event:`, result.message);
    }

    return result;
};

export const sendMultipleDocumentsEvent = async (personId, documentType, files) => {
    const formData = new FormData();

    formData.append('eventId', generateEventId());
    formData.append('eventType', 'document_upload');
    formData.append('timestamp', new Date().toISOString());
    formData.append('personId', personId);
    formData.append('documentType', documentType);
    formData.append('status', 'ontvangen');
    formData.append('fileCount', files.length.toString());

    files.forEach((file, index) => {
        if (file && file instanceof File) {
            const ext = file.name.includes('.') ? '.' + file.name.split('.').pop() : '';
            const baseName = file.name.includes('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
            const newFileName = `${baseName}_${documentType}_${index + 1}${ext}`;

            formData.append(`file_${index}`, file, newFileName);
            formData.append(`fileName_${index}`, newFileName);
            formData.append(`originalFileName_${index}`, file.name);
            formData.append(`fileType_${index}`, file.type);
            formData.append(`fileSize_${index}`, file.size.toString());
        }
    });

    console.log(`[Webhook] Sending multi-file document_upload event:`, {
        personId,
        documentType,
        fileCount: files.length
    });

    const result = await fetchWithRetry(WEBHOOK_URL, {
        method: 'POST',
        body: formData
    });

    if (result.ok) {
        console.log(`[Webhook] Successfully sent multi-file document_upload event`);
    } else {
        console.error(`[Webhook] Failed to send multi-file document_upload event:`, result.message);
    }

    return result;
};

export const sendApplicationSubmitEvent = async (applicationData) => {
    return sendWebhookData('application_submit', {
        data: applicationData
    });
};

const translations = {
    roles: {
        'Hoofdhuurder': 'Main Tenant',
        'Medehuurder': 'Co-Tenant',
        'Garantsteller': 'Guarantor'
    },
    workStatus: {
        'werknemer': 'Employee',
        'ondernemer': 'Entrepreneur',
        'zzper': 'Freelancer',
        'student': 'Student',
        'gepensioneerd': 'Retired',
        'werkzoekend': 'Job Seeker'
    },
    documentStatus: {
        'ontvangen': 'Received',
        'ontbreekt': 'Missing',
        'gecontroleerd': 'Verified'
    },
    documentTypes: {
        'id': 'ID Document',
        'arbeidscontract': 'Employment Contract',
        'loonstroken': 'Salary Slips',
        'werkgeversverklaring': 'Employer Statement',
        'bankafschriften': 'Bank Statements',
        'kvk': 'Chamber of Commerce',
        'jaarrekening': 'Annual Report'
    }
};

const translateValue = (category, value) => {
    if (!value) return { nl: value, en: value };
    const enValue = translations[category]?.[value.toLowerCase()] || value;
    return { nl: value, en: enValue };
};

export const sendLetterOfIntentEvent = async (loiData) => {
    const formData = new FormData();

    formData.append('eventId', generateEventId());
    formData.append('eventType', 'loi_signed');
    formData.append('timestamp', new Date().toISOString());

    let fileIndex = 0;

    const tenants = loiData.tenantData?.personen?.map((person, personIndex) => {
        const roleTranslated = translateValue('roles', person.rol);
        const workStatusTranslated = translateValue('workStatus', person.werkstatus);

        const documentsData = (person.documenten || []).map((doc, docIndex) => {
            const typeTranslated = translateValue('documentTypes', doc.type);
            const statusTranslated = translateValue('documentStatus', doc.status);

            if (doc.file && doc.file instanceof File) {
                const ext = doc.file.name.includes('.') ? '.' + doc.file.name.split('.').pop() : '';
                const baseName = doc.file.name.includes('.') ? doc.file.name.substring(0, doc.file.name.lastIndexOf('.')) : doc.file.name;
                const newFileName = `${baseName}_${doc.type}_${person.naam?.replace(/\s+/g, '_') || 'tenant'}${ext}`;

                formData.append(`file_${fileIndex}`, doc.file, newFileName);
                formData.append(`file_${fileIndex}_personIndex`, personIndex.toString());
                formData.append(`file_${fileIndex}_documentType`, doc.type);
                formData.append(`file_${fileIndex}_personName`, person.naam || '');
                fileIndex++;
            }

            if (doc.files && Array.isArray(doc.files)) {
                doc.files.forEach((file, i) => {
                    if (file && file instanceof File) {
                        const ext = file.name.includes('.') ? '.' + file.name.split('.').pop() : '';
                        const baseName = file.name.includes('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
                        const newFileName = `${baseName}_${doc.type}_${i + 1}_${person.naam?.replace(/\s+/g, '_') || 'tenant'}${ext}`;

                        formData.append(`file_${fileIndex}`, file, newFileName);
                        formData.append(`file_${fileIndex}_personIndex`, personIndex.toString());
                        formData.append(`file_${fileIndex}_documentType`, doc.type);
                        formData.append(`file_${fileIndex}_personName`, person.naam || '');
                        fileIndex++;
                    }
                });
            }

            return {
                type: typeTranslated,
                status: statusTranslated,
                fileName: doc.file?.name || (doc.files ? doc.files.map(f => f.name).join(', ') : null)
            };
        });

        return {
            role: roleTranslated,
            name: person.naam,
            email: person.email,
            phone: person.telefoon || person.whatsapp,
            income: person.inkomen,
            workStatus: workStatusTranslated,
            address: person.adres,
            postcode: person.postcode,
            city: person.woonplaats,
            documents: documentsData
        };
    }) || [];

    formData.append('fileCount', fileIndex.toString());

    if (loiData.signatureImage && loiData.signatureImage instanceof File) {
        formData.append('signature', loiData.signatureImage, 'signature.png');
        formData.append('hasSignature', 'true');
    }

    formData.append('bidAmount', loiData.bidAmount?.toString() || '');
    formData.append('startDate', loiData.startDate || '');
    formData.append('motivation', loiData.motivation || '');
    formData.append('monthsAdvance', loiData.monthsAdvance?.toString() || '');

    formData.append('propertyAddress', loiData.property?.adres || '');
    formData.append('rentPrice', loiData.property?.voorwaarden?.huurprijs?.toString() || '');
    formData.append('deposit', loiData.property?.voorwaarden?.waarborgsom?.toString() || '');
    formData.append('serviceCosts', loiData.property?.voorwaarden?.servicekosten?.toString() || '');

    formData.append('tenantCount', tenants.length.toString());
    tenants.forEach((tenant, idx) => {
        formData.append(`tenant_${idx}_role_nl`, tenant.role?.nl || '');
        formData.append(`tenant_${idx}_role_en`, tenant.role?.en || '');
        formData.append(`tenant_${idx}_name`, tenant.name || '');
        formData.append(`tenant_${idx}_email`, tenant.email || '');
        formData.append(`tenant_${idx}_phone`, tenant.phone || '');
        formData.append(`tenant_${idx}_income`, tenant.income?.toString() || '');
        formData.append(`tenant_${idx}_workStatus_nl`, tenant.workStatus?.nl || '');
        formData.append(`tenant_${idx}_workStatus_en`, tenant.workStatus?.en || '');
        formData.append(`tenant_${idx}_address`, tenant.address || '');
        formData.append(`tenant_${idx}_postcode`, tenant.postcode || '');
        formData.append(`tenant_${idx}_city`, tenant.city || '');
        formData.append(`tenant_${idx}_documentCount`, (tenant.documents?.length || 0).toString());

        tenant.documents?.forEach((doc, docIdx) => {
            formData.append(`tenant_${idx}_doc_${docIdx}_type_nl`, doc.type?.nl || '');
            formData.append(`tenant_${idx}_doc_${docIdx}_type_en`, doc.type?.en || '');
            formData.append(`tenant_${idx}_doc_${docIdx}_status_nl`, doc.status?.nl || '');
            formData.append(`tenant_${idx}_doc_${docIdx}_status_en`, doc.status?.en || '');
            formData.append(`tenant_${idx}_doc_${docIdx}_fileName`, doc.fileName || '');
        });
    });

    formData.append('conditionsAccepted', loiData.conditionsAccepted?.toString() || 'false');
    formData.append('brokerFeeAccepted', loiData.brokerFeeAccepted?.toString() || 'false');
    formData.append('signedAt', new Date().toISOString());
    formData.append('phoneNumber', loiData.phoneNumber || '');

    console.log(`[Webhook] Sending loi_signed event with ${fileIndex} files`);

    const result = await fetchWithRetry(WEBHOOK_URL, {
        method: 'POST',
        body: formData
    });

    if (result.ok) {
        console.log(`[Webhook] Successfully sent loi_signed event`);
    } else {
        console.error(`[Webhook] Failed to send loi_signed event:`, result.message);
    }

    return result;
};
