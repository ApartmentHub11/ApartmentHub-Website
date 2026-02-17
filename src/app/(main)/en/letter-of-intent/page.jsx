'use client';

import ProtectedRoute from '@/components/common/ProtectedRoute';
import LetterOfIntent from '@/pages/LetterOfIntent';

export default function Page() {
    return (
        <ProtectedRoute>
            <LetterOfIntent />
        </ProtectedRoute>
    );
}
