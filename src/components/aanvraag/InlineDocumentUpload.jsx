
import React, { useState } from 'react';
import Button from '../ui/Button';
import Badge from '../ui/Badge';
import { Upload, CheckCircle, AlertCircle, File, X } from 'lucide-react';
import { toast } from 'sonner';
import { translations } from '../../data/translations';
import styles from './DocumentUpload.module.css';

const InlineDocumentUpload = ({
    documentType,
    description,
    verplicht = true,
    status,
    fileName,
    onUpload,
    onRemove,
    lang = 'nl'
}) => {
    const [isDragging, setIsDragging] = useState(false);
    const [uploading, setUploading] = useState(false);

    const uploadText = (key) => {
        try {
            return translations.documents[lang].upload[key];
        } catch (e) {
            return translations.documents['nl'].upload[key] || key;
        }
    };

    const handleDrop = (e) => {
        e.preventDefault();
        setIsDragging(false);

        const file = e.dataTransfer.files[0];
        if (file) {
            handleFileUpload(file);
        }
    };

    const handleFileSelect = (e) => {
        const file = e.target.files?.[0];
        if (file) {
            handleFileUpload(file);
        }
    };

    const handleFileUpload = async (file) => {
        // Validate file type
        const allowedTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'];
        if (!allowedTypes.includes(file.type)) {
            toast.error(uploadText('invalidFileType'));
            return;
        }

        // Validate file size (10MB)
        if (file.size > 10 * 1024 * 1024) {
            toast.error(uploadText('fileTooLarge'));
            return;
        }

        setUploading(true);

        // Simulating upload/extraction delay
        setTimeout(() => {
            onUpload(file);
            setUploading(false);
        }, 800);
    };

    if (status === "ontvangen" && fileName) {
        return (
            <div className={`${styles.container} ${styles.complete}`}>
                <div className={`${styles.iconWrapper} ${styles.iconComplete}`}>
                    <CheckCircle className={styles.statusIcon} />
                </div>
                <div className={styles.content}>
                    <div className={styles.header}>
                        <p className={styles.title}>{documentType}</p>
                        <span className={`${styles.badge} ${styles.badgeComplete}`}>
                            {uploadText('complete')}
                        </span>
                    </div>
                    <p className={styles.description}>{fileName}</p>
                </div>
                {onRemove && (
                    <div className={styles.actions}>
                        <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={onRemove}
                            className="bg-red-50 text-red-600 hover:bg-red-100"
                        >
                            <X className="h-4 w-4" />
                        </Button>
                    </div>
                )}
            </div>
        );
    }

    return (
        <div
            onDragOver={(e) => {
                e.preventDefault();
                setIsDragging(true);
            }}
            onDragLeave={() => setIsDragging(false)}
            onDrop={handleDrop}
            className={`${styles.container} ${isDragging ? styles.dragging : ''}`}
        >
            <div className={`${styles.iconWrapper} ${verplicht ? styles.iconRequired : styles.iconDefault}`}>
                {verplicht ? (
                    <AlertCircle className={styles.statusIcon} />
                ) : (
                    <Upload className={styles.statusIcon} />
                )}
            </div>

            <div className={styles.content}>
                <div className={styles.header}>
                    <p className={styles.title}>{documentType}</p>
                    {!verplicht && (
                        <span className={`${styles.badge} ${styles.badgeOptional}`}>
                            {uploadText('optional')}
                        </span>
                    )}
                </div>

                {description && <p className={styles.description}>{description}</p>}

                <div className={styles.metaInfo}>
                    <div className={styles.metaRow}>
                        <Upload className={styles.metaIcon} />
                        <span className={styles.uploadStatus}>
                            {uploading ? uploadText('uploading') : uploadText('dragOrClick')}
                        </span>
                    </div>
                    <div className={styles.metaRow}>
                        <File className={styles.metaIcon} />
                        <span>{uploadText('fileTypes')} • Max 10MB</span>
                    </div>
                </div>
            </div>

            <div className={styles.actions}>
                <label className={styles.uploadButtonLabel}>
                    <input
                        type="file"
                        className={styles.fileInput}
                        accept=".pdf,.jpg,.jpeg,.png,.webp"
                        onChange={handleFileSelect}
                        disabled={uploading}
                    />
                    <div className={styles.uploadButton}>
                        <Upload className={styles.metaIcon} />
                        <span>Upload</span>
                    </div>
                </label>
            </div>
        </div>
    );
};

export default InlineDocumentUpload;
