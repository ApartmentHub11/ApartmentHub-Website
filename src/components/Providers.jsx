'use client';

import { Provider } from 'react-redux';
import { store } from '@/app/store';
import { AuthProvider } from '@/contexts/AuthContext';
import { Toaster } from 'sonner';

export default function Providers({ children }) {
    return (
        <Provider store={store}>
            <AuthProvider>
                <Toaster position="top-center" richColors />
                {children}
            </AuthProvider>
        </Provider>
    );
}
