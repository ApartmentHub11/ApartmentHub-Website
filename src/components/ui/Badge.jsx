import React from 'react';
import styles from './Badge.module.css';
import clsx from 'clsx';

/**
 * Badge component
 * @param {'default'|'secondary'|'success'|'warning'|'error'|'outline'} variant
 * @param {'sm'|'default'|'lg'} size
 */
const Badge = ({
    children,
    variant = 'default',
    size = 'default',
    pulse = false,
    className,
    ...props
}) => {
    return (
        <span
            className={clsx(
                styles.badge,
                styles[variant],
                size !== 'default' && styles[size],
                pulse && styles.pulse,
                className
            )}
            {...props}
        >
            {children}
        </span>
    );
};

export default Badge;
