import { Search } from "lucide-react";
import type { InputHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from "react";

interface FieldProps {
  label: string;
  htmlFor: string;
  requerido?: boolean;
  error?: string;
  hint?: ReactNode;
  children: ReactNode;
}

export function Field({ label, htmlFor, requerido, error, hint, children }: FieldProps) {
  return (
    <div className="tc-field">
      <label className="tc-field__label" htmlFor={htmlFor}>
        {label} {requerido ? <span className="tc-field__req" aria-hidden="true">*</span> : null}
      </label>
      {children}
      {error ? (
        <span className="tc-field__error" role="alert">
          {error}
        </span>
      ) : hint ? (
        <span className="tc-field__hint">{hint}</span>
      ) : null}
    </div>
  );
}

interface TextInputProps extends InputHTMLAttributes<HTMLInputElement> {
  invalido?: boolean;
}

export function TextInput({ invalido, className, ...rest }: TextInputProps) {
  return (
    <input
      className={["tc-input", className ?? ""].filter(Boolean).join(" ")}
      aria-invalid={invalido ? "true" : undefined}
      {...rest}
    />
  );
}

interface SelectInputProps extends SelectHTMLAttributes<HTMLSelectElement> {
  invalido?: boolean;
}

export function SelectInput({ invalido, className, children, ...rest }: SelectInputProps) {
  return (
    <select
      className={["tc-select", className ?? ""].filter(Boolean).join(" ")}
      aria-invalid={invalido ? "true" : undefined}
      {...rest}
    >
      {children}
    </select>
  );
}

interface TextAreaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  invalido?: boolean;
}

export function TextArea({ invalido, className, ...rest }: TextAreaProps) {
  return (
    <textarea
      className={["tc-textarea", className ?? ""].filter(Boolean).join(" ")}
      aria-invalid={invalido ? "true" : undefined}
      {...rest}
    />
  );
}

export function SearchInput({ className, ...rest }: TextInputProps) {
  return (
    <div className="tc-search">
      <span className="tc-search__icon" aria-hidden="true">
        <Search size={16} />
      </span>
      <TextInput className={className} type="search" {...rest} />
    </div>
  );
}

export function Switch({
  etiqueta,
  id,
  checked,
  onChange,
  disabled,
}: {
  etiqueta: string;
  id: string;
  checked: boolean;
  onChange: (valor: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <label className="tc-switch" htmlFor={id}>
      <input
        id={id}
        type="checkbox"
        checked={checked}
        disabled={disabled}
        onChange={(e) => onChange(e.target.checked)}
      />
      {etiqueta}
    </label>
  );
}
