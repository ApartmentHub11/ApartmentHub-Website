import React, { useEffect } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';
import styles from './Modal.module.css';
import clsx from 'clsx';

/**
 * Modal component with portal rendering
 */
const Modal = ({
    open,
    onClose,
    children,
    size = 'default',
    showCloseButton = true,
    className
}) => {
    // Close on escape key
    useEffect(() => {
        const handleEscape = (e) => {
            if (e.key === 'Escape') {
                onClose?.();
            }
        };

        if (open) {
            document.addEventListener('keydown', handleEscape);
            document.body.style.overflow = 'hidden';
        }

        return () => {
            document.removeEventListener('keydown', handleEscape);
            document.body.style.overflow = '';
        };
    }, [open, onClose]);

    if (!open) return null;

    return createPortal(
        <div className={styles.overlay} onClick={onClose}>
            <div
                className={clsx(
                    styles.modal,
                    size === 'lg' && styles.modalLg,
                    size === 'xl' && styles.modalXl,
                    className
                )}
                onClick={(e) => e.stopPropagation()}
            >
                {showCloseButton && (
                    <button className={styles.closeButton} onClick={onClose}>
                        <X size={20} />
                    </button>
                )}
                {children}
            </div>
        </div>,
        document.body
    );
};

export const ModalHeader = ({ children, className }) => (
    <div className={clsx(styles.header, className)}>{children}</div>
);

export const ModalTitle = ({ children, className }) => (
    <h2 className={clsx(styles.title, className)}>{children}</h2>
);

export const ModalDescription = ({ children, className }) => (
    <p className={clsx(styles.description, className)}>{children}</p>
);

export const ModalContent = ({ children, className }) => (
    <div className={clsx(styles.content, className)}>{children}</div>
);

export const ModalFooter = ({ children, className }) => (
    <div className={clsx(styles.footer, className)}>{children}</div>
);

export default Modal;
