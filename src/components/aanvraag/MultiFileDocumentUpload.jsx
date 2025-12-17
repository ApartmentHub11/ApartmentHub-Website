
import React, { useState } from 'react';
import Button from '../ui/Button';
import Badge from '../ui/Badge';
import { Upload, X, File, AlertCircle, CheckCircle } from 'lucide-react';
import { toast } from 'sonner';
import { translations } from '../../data/translations';
import styles from './DocumentUpload.module.css';

const MultiFileDocumentUpload = ({
    documentType,
    description,
    verplicht = true,
    maxFiles = 5,
    minFiles = 1,
    uploadedFiles = [],
    onUpload,
    onRemove,
    lang = 'nl'
}) => {
    const [isDragging, setIsDragging] = useState(false);
    const [uploading, setUploading] = useState(false);

    // Helper to get text from translations
    const t = (key, params = {}) => {
        let text = "";
        try {
            text = translations.multiFileUpload[lang][key] || translations.multiFileUpload['nl'][key] || key;
        } catch (e) {
            text = key;
        }

        // Replace params
        Object.keys(params).forEach(param => {
            text = text.replace(`{{${param}}}`, params[param]);
        });

        return text;
    };

    const commonText = (key) => {
        try {
            return translations.documents[lang].upload[key] || translations.documents['nl'].upload[key];
        } catch (e) {
            return key;
        }
    }

    const handleDrop = (e) => {
        e.preventDefault();
        setIsDragging(false);

        const files = Array.from(e.dataTransfer.files);
        handleFilesUpload(files);
    };

    const handleFileSelect = (e) => {
        const files = Array.from(e.target.files || []);
        handleFilesUpload(files);
    };

    const handleFilesUpload = async (files) => {
        // Check if adding these files would exceed the limit
        const remainingSlots = maxFiles - uploadedFiles.length;
        if (files.length > remainingSlots) {
            toast.error(t('maxFilesError', { max: maxFiles, remaining: remainingSlots }));
            return;
        }

        // Validate file types and sizes
        const allowedTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'];
        const validFiles = [];

        for (const file of files) {
            if (!allowedTypes.includes(file.type)) {
                toast.error(t('invalidFileType', { fileName: file.name }));
                continue;
            }

            if (file.size > 10 * 1024 * 1024) { // 10MB limit
                toast.error(t('fileTooLarge', { fileName: file.name }));
                continue;
            }

            validFiles.push(file);
        }

        if (validFiles.length === 0) return;

        setUploading(true);

        // Simulate upload delay
        setTimeout(() => {
            const newFiles = [...uploadedFiles, ...validFiles];
            onUpload(newFiles);
            setUploading(false);
            toast.success(t('filesUploaded', { count: validFiles.length }));
        }, 800);
    };

    const isComplete = uploadedFiles.length >= minFiles;
    const canAddMore = uploadedFiles.length < maxFiles;

    return (
        <div className={`space-y-3 ${isComplete ? 'opacity-100' : 'opacity-100'}`}>
            <div
                onDragOver={(e) => {
                    e.preventDefault();
                    setIsDragging(true);
                }}
                onDragLeave={() => setIsDragging(false)}
                onDrop={handleDrop}
                className={`${styles.container} ${isDragging ? styles.dragging : ''} ${isComplete ? styles.complete : ''}`}
            >
                <div className={`${styles.iconWrapper} ${isComplete ? styles.iconComplete : verplicht ? styles.iconRequired : styles.iconDefault
                    }`}>
                    {isComplete ? (
                        <CheckCircle className={styles.statusIcon} />
                    ) : (
                        <AlertCircle className={styles.statusIcon} />
                    )}
                </div>

                <div className={styles.content}>
                    <div className={styles.header}>
                        <p className={styles.title}>{documentType}</p>
                        {!verplicht && (
                            <span className={`${styles.badge} ${styles.badgeOptional}`}>
                                {t('optional')}
                            </span>
                        )}
                        {isComplete && (
                            <span className={`${styles.badge} ${styles.badgeComplete}`}>
                                {t('complete')}
                            </span>
                        )}
                        <span className={`${styles.badge} ${styles.badgeOptional} ml-2`}>
                            {uploadedFiles.length} / {maxFiles}
                        </span>
                    </div>

                    {description && <p className={styles.description}>{description}</p>}

                    <div className={styles.metaInfo}>
                        <div className={styles.metaRow}>
                            <Upload className={styles.metaIcon} />
                            <span className={styles.uploadStatus}>
                                {uploading ? commonText('uploading') : canAddMore ? t('uploadMinMax', { min: minFiles, max: maxFiles }) : t('complete')}
                            </span>
                        </div>
                        <div className={styles.metaRow}>
                            <File className={styles.metaIcon} />
                            <span>{commonText('fileTypes')} • Max 10MB</span>
                        </div>
                    </div>
                </div>

                {canAddMore && (
                    <div className={styles.actions}>
                        <label className={styles.uploadButtonLabel}>
                            <input
                                type="file"
                                multiple
                                className={styles.fileInput}
                                accept=".pdf,.jpg,.jpeg,.png,.webp"
                                onChange={handleFileSelect}
                                disabled={uploading}
                            />
                            <div className={`${styles.uploadButton} ${uploading ? 'opacity-50' : ''}`}>
                                <Upload className={styles.metaIcon} />
                                <span>Upload</span>
                            </div>
                        </label>
                    </div>
                )}
            </div>

            {/* File List */}
            {uploadedFiles.length > 0 && (
                <div className={styles.fileList}>
                    {uploadedFiles.map((file, index) => (
                        <div key={index} className={styles.fileItem}>
                            <div className={styles.fileInfo}>
                                <div className={styles.fileIconWrapper}>
                                    <File className={styles.metaIcon} />
                                </div>
                                <div>
                                    <p className={styles.fileName}>{file.name}</p>
                                    <p className={styles.fileSize}>{(file.size / 1024 / 1024).toFixed(2)} MB</p>
                                </div>
                            </div>

                            <button
                                type="button"
                                onClick={() => onRemove(index)}
                                className={styles.removeButton}
                            >
                                <X className={styles.metaIcon} />
                            </button>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};

export default MultiFileDocumentUpload;
