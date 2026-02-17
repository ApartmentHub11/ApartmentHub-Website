import js from '@eslint/js';
import nextPlugin from '@next/eslint-plugin-next';
import reactPlugin from 'eslint-plugin-react';
import reactHooksPlugin from 'eslint-plugin-react-hooks';
import jsxA11yPlugin from 'eslint-plugin-jsx-a11y';
import globals from 'globals';

export default [
    {
        ignores: [
            '.next/**',
            'node_modules/**',
            'out/**',
            'dist/**',
        ],
    },
    js.configs.recommended,
    {
        files: ['**/*.{js,jsx,mjs,cjs}'],
        languageOptions: {
            ecmaVersion: 'latest',
            sourceType: 'module',
            globals: {
                ...globals.browser,
                ...globals.node,
            },
            parserOptions: {
                ecmaFeatures: {
                    jsx: true,
                },
            },
        },
        settings: {
            react: {
                version: 'detect',
            },
        },
        plugins: {
            '@next/next': nextPlugin,
            react: reactPlugin,
            'react-hooks': reactHooksPlugin,
            'jsx-a11y': jsxA11yPlugin,
        },
        rules: {
            ...reactPlugin.configs.recommended.rules,
            ...reactHooksPlugin.configs.recommended.rules,
            ...jsxA11yPlugin.configs.recommended.rules,
            ...nextPlugin.configs['core-web-vitals'].rules,

            // React 17+/Next.js doesn't require React in scope
            'react/react-in-jsx-scope': 'off',
            'react/jsx-uses-react': 'off',

            // This codebase doesn't use PropTypes
            'react/prop-types': 'off',

            // Accessibility: don't fail builds on legacy autofocus usage
            'jsx-a11y/no-autofocus': 'off',

            // Keep unused vars as warnings to avoid blocking during migration
            'no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^React$' }],

            // Migration ergonomics: avoid blocking on a11y/style issues
            'no-constant-binary-expression': 'off',
            'react/no-unescaped-entities': 'warn',
            'react-hooks/immutability': 'off',
            'react-hooks/refs': 'off',
            'react-hooks/static-components': 'off',
            'react-hooks/set-state-in-effect': 'off',
            'react/display-name': 'off',

            'jsx-a11y/click-events-have-key-events': 'off',
            'jsx-a11y/no-static-element-interactions': 'off',
            'jsx-a11y/iframe-has-title': 'off',
            'jsx-a11y/label-has-associated-control': 'off',
            'jsx-a11y/no-noninteractive-tabindex': 'off',
            'jsx-a11y/no-noninteractive-element-interactions': 'off',
        },
    },
];

