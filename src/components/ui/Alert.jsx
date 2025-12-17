import React from 'react';
import { AlertCircle, CheckCircle, Info, AlertTriangle, X } from 'lucide-react';
import styles from './Alert.module.css';
import clsx from 'clsx';

const icons = {
    info: Info,
    success: CheckCircle,
    warning: AlertTriangle,
    error: AlertCircle
};

/**
 * Alert component for notifications
 * @param {'info'|'success'|'warning'|'error'} variant
 */
const Alert = ({
    children,
    variant = 'info',
    title,
    onClose,
    className,
    showIcon = true
}) => {
    const Icon = icons[variant];

    return (
        <div className={clsx(styles.alert, styles[variant], className)} role="alert">
            {showIcon && (
                <Icon className={styles.icon} size={20} />
            )}
            <div className={styles.content}>
                {title && <div className={styles.title}>{title}</div>}
                <div className={styles.description}>{children}</div>
            </div>
            {onClose && (
                <button className={styles.closeBtn} onClick={onClose}>
                    <X size={16} />
                </button>
            )}
        </div>
    );
};

export default Alert;
