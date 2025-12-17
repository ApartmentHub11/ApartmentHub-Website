import React from 'react';
import styles from './Card.module.css';
import clsx from 'clsx';

export const Card = ({ children, className, gradientBorder, shadow, hoverShadow, ...props }) => {
    return (
        <div
            className={clsx(
                styles.card,
                gradientBorder && styles.gradientBorderMyrtle,
                shadow === 'lg' && styles.shadowLg,
                shadow === 'xl' && styles.shadowXl,
                hoverShadow && styles.hoverShadow,
                className
            )}
            {...props}
        >
            {children}
        </div>
    );
};

export const CardHeader = ({ children, className, ...props }) => {
    return (
        <div className={clsx(styles.cardHeader, className)} {...props}>
            {children}
        </div>
    );
};

export const CardTitle = ({ children, className, as: Component = 'h3', ...props }) => {
    return (
        <Component className={clsx(styles.cardTitle, className)} {...props}>
            {children}
        </Component>
    );
};

export const CardDescription = ({ children, className, ...props }) => {
    return (
        <p className={clsx(styles.cardDescription, className)} {...props}>
            {children}
        </p>
    );
};

export const CardContent = ({ children, className, ...props }) => {
    return (
        <div className={clsx(styles.cardContent, className)} {...props}>
            {children}
        </div>
    );
};

export const CardFooter = ({ children, className, ...props }) => {
    return (
        <div className={clsx(styles.cardFooter, className)} {...props}>
            {children}
        </div>
    );
};
