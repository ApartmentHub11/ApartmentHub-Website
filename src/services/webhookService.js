const WEBHOOK_URL = 'https://davidvanwachem.app.n8n.cloud/webhook/get-agenda-page-details';

const generateEventId = () => {
    return 'evt_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
};

export const sendWebhookData = async (eventType, data) => {
    const payload = {
        eventId: generateEventId(),
        eventType,
        timestamp: new Date().toISOString(),
        ...data
    };

    try {
        console.log(`[Webhook] Sending ${eventType} event:`, payload);

        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            console.error(`[Webhook] Failed with status ${response.status}`);
            return { ok: false, message: `HTTP ${response.status}` };
        }

        console.log(`[Webhook] Successfully sent ${eventType} event`);
        return { ok: true };
    } catch (error) {
        console.error('[Webhook] Error sending data:', error);
        return { ok: false, message: error.message };
    }
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

    try {
        console.log(`[Webhook] Sending document_upload event via multipart:`, {
            personId,
            documentType,
            fileName: file?.name
        });

        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            console.error(`[Webhook] Failed with status ${response.status}`);
            return { ok: false, message: `HTTP ${response.status}` };
        }

        console.log(`[Webhook] Successfully sent document_upload event`);
        return { ok: true };
    } catch (error) {
        console.error('[Webhook] Error sending document:', error);
        return { ok: false, message: error.message };
    }
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

    try {
        console.log(`[Webhook] Sending multi-file document_upload event:`, {
            personId,
            documentType,
            fileCount: files.length
        });

        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            console.error(`[Webhook] Failed with status ${response.status}`);
            return { ok: false, message: `HTTP ${response.status}` };
        }

        console.log(`[Webhook] Successfully sent multi-file document_upload event`);
        return { ok: true };
    } catch (error) {
        console.error('[Webhook] Error sending documents:', error);
        return { ok: false, message: error.message };
    }
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

    const jsonData = {
        bidAmount: loiData.bidAmount,
        startDate: loiData.startDate,
        motivation: loiData.motivation,
        monthsAdvance: loiData.monthsAdvance,
        property: {
            address: loiData.property?.adres,
            rentPrice: loiData.property?.voorwaarden?.huurprijs,
            deposit: loiData.property?.voorwaarden?.waarborgsom,
            serviceCosts: loiData.property?.voorwaarden?.servicekosten
        },
        tenants,
        conditionsAccepted: loiData.conditionsAccepted,
        brokerFeeAccepted: loiData.brokerFeeAccepted,
        signedAt: new Date().toISOString(),
        phoneNumber: loiData.phoneNumber
    };

    formData.append('data', JSON.stringify(jsonData));

    try {
        console.log(`[Webhook] Sending loi_signed event with ${fileIndex} files:`, jsonData);

        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            console.error(`[Webhook] Failed with status ${response.status}`);
            return { ok: false, message: `HTTP ${response.status}` };
        }

        console.log(`[Webhook] Successfully sent loi_signed event`);
        return { ok: true };
    } catch (error) {
        console.error('[Webhook] Error sending LOI:', error);
        return { ok: false, message: error.message };
    }
};
