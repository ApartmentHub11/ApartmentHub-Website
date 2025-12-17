import React, { forwardRef } from 'react';
import styles from './Input.module.css';
import clsx from 'clsx';

/**
 * Input component with label and error handling
 */
const Input = forwardRef(({
    className,
    label,
    error,
    description,
    required,
    prefix,
    suffix,
    size,
    ...props
}, ref) => {
    return (
        <div className={styles.inputWrapper}>
            {label && (
                <label className={styles.label}>
                    {label}
                    {required && <span className={styles.required}>*</span>}
                </label>
            )}
            <div className={styles.inputContainer}>
                {prefix && <span className={styles.prefix}>{prefix}</span>}
                <input
                    ref={ref}
                    className={clsx(
                        styles.input,
                        error && styles.inputError,
                        prefix && styles.hasPrefix,
                        suffix && styles.hasSuffix,
                        size === 'sm' && styles.sm,
                        size === 'lg' && styles.lg,
                        size === 'xl' && styles.xlInput,
                        className
                    )}
                    {...props}
                />
                {suffix && <span className={styles.suffix}>{suffix}</span>}
            </div>
            {description && !error && (
                <p className={styles.description}>{description}</p>
            )}
            {error && (
                <p className={styles.error}>{error}</p>
            )}
        </div>
    );
});

Input.displayName = 'Input';

export default Input;
