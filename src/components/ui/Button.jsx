import React from 'react';
import styles from './Button.module.css';
import clsx from 'clsx';

/**
 * Button component with variants
 * @param {Object} props
 * @param {'default'|'secondary'|'outline'|'ghost'|'destructive'|'link'} props.variant
 * @param {'sm'|'md'|'lg'|'xl'} props.size
 * @param {boolean} props.loading
 * @param {boolean} props.fullWidth
 * @param {boolean} props.iconOnly
 */
const Button = ({
    children,
    className,
    variant = 'default',
    size = 'md',
    loading = false,
    fullWidth = false,
    iconOnly = false,
    disabled,
    type = 'button',
    ...props
}) => {
    return (
        <button
            type={type}
            disabled={disabled || loading}
            className={clsx(
                styles.button,
                styles[variant],
                styles[size],
                fullWidth && styles.fullWidth,
                iconOnly && styles.iconOnly,
                loading && styles.loading,
                className
            )}
            {...props}
        >
            {loading && <span className={styles.spinner} />}
            {children}
        </button>
    );
};

export default Button;
