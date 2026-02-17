import Navbar from '@/components/layout/Navbar';
import Footer from '@/components/layout/Footer';
import ScrollToTop from '@/components/common/ScrollToTop';
import styles from '@/components/layout/Layout.module.css';

export default function MainLayout({ children }) {
    return (
        <div className={styles.layout}>
            <ScrollToTop />
            <Navbar />
            <main className={styles.main}>
                {children}
            </main>
            <Footer />
        </div>
    );
}
