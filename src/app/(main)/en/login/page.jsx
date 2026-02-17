import Login from '@/pages/Login';
import { Suspense } from 'react';

export default function Page() {
    return (
        <Suspense fallback={null}>
            <Login />
        </Suspense>
    );
}
