import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatPrice(price: number | string | null | undefined): string {
  if (!price) return '$0'
  const num = typeof price === 'string' ? parseFloat(price) : price
  if (isNaN(num)) return '$0'
  return `$${num % 1 === 0 ? num.toFixed(0) : num.toFixed(2)}`
}

export function formatDistance(meters: number | null | undefined): string {
  if (!meters) return ''
  const miles = meters * 0.000621371
  return `${miles.toFixed(1)} mi`
}
