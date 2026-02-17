'use client';

import ProtectedRoute from '@/components/common/ProtectedRoute';
import Aanvraag from '@/pages/Aanvraag';

export default function Page() {
    return (
        <ProtectedRoute>
            <Aanvraag />
        </ProtectedRoute>
    );
}
