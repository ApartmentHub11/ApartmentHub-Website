import React from 'react';
import styles from './Progress.module.css';
import clsx from 'clsx';

/**
 * Progress bar component
 */
const Progress = ({
    value = 0,
    max = 100,
    label,
    showValue = true,
    variant = 'default',
    size = 'default',
    striped = false,
    className
}) => {
    const percentage = Math.min(Math.max((value / max) * 100, 0), 100);

    const getVariantClass = () => {
        if (variant === 'auto') {
            if (percentage >= 100) return styles.barSuccess;
            if (percentage >= 50) return '';
            if (percentage >= 25) return styles.barWarning;
            return styles.barError;
        }
        return styles[`bar${variant.charAt(0).toUpperCase() + variant.slice(1)}`];
    };

    return (
        <div className={clsx(styles.progressContainer, className)}>
            {(label || showValue) && (
                <div className={styles.label}>
                    {label && <span className={styles.labelText}>{label}</span>}
                    {showValue && (
                        <span className={styles.labelValue}>{Math.round(percentage)}%</span>
                    )}
                </div>
            )}
            <div className={clsx(styles.track, size === 'lg' && styles.trackLg)}>
                <div
                    className={clsx(
                        styles.bar,
                        getVariantClass(),
                        striped && styles.striped
                    )}
                    style={{ width: `${percentage}%` }}
                    role="progressbar"
                    aria-valuenow={value}
                    aria-valuemin={0}
                    aria-valuemax={max}
                />
            </div>
        </div>
    );
};

export default Progress;
