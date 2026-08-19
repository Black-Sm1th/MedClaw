import { parse } from 'pptxtojson'
import { nanoid } from 'nanoid'
import type { Slide, PPTElement } from '@/types/slides'

type ParsedPptx = {
  slides?: any[]
  size?: { width?: number; height?: number }
  themeColors?: string[]
}

const RECT_PATH = 'M 0 0 L 200 0 L 200 200 L 0 200 Z'
const ELLIPSE_PATH = 'M 100 0 A 100 100 0 1 1 100 200 A 100 100 0 1 1 100 0 Z'

function color(value: unknown, fallback = '#ffffff') {
  return typeof value === 'string' && value ? value : fallback
}

function fillColor(fill: any, fallback = '#ffffff') {
  if (!fill) return fallback
  if (fill.type === 'color') return color(fill.value, fallback)
  if (fill.type === 'gradient' && Array.isArray(fill.value?.colors)) {
    return color(fill.value.colors[0]?.color, fallback)
  }
  return fallback
}

function outline(item: any) {
  if (!item?.borderWidth) return undefined
  return {
    width: Number(item.borderWidth) || 0,
    color: color(item.borderColor, '#000000'),
    style: item.borderType === 'dashed' ? 'dashed' as const : 'solid' as const,
  }
}

function link(value: unknown) {
  return typeof value === 'string' && value ? { type: 'web' as const, target: value } : undefined
}

function bounds(item: any, scale: number) {
  return {
    left: Number(item.left || 0) * scale,
    top: Number(item.top || 0) * scale,
    width: Math.max(1, Number(item.width || 1) * scale),
    height: Math.max(1, Number(item.height || 1) * scale),
    rotate: Number(item.rotate || 0),
  }
}

function elementFromParsed(item: any, scale: number, index: number): PPTElement | null {
  const b = bounds(item, scale)
  const common = { id: nanoid(10), ...b, link: link(item.link) }

  if (item.type === 'text') {
    return {
      type: 'text',
      ...common,
      content: item.content || '',
      defaultFontName: 'Arial',
      defaultColor: '#000000',
      outline: outline(item),
      fill: fillColor(item.fill, 'transparent'),
    } as PPTElement
  }

  if (item.type === 'image') {
    const src = item.base64 || item.src || (item.blob ? URL.createObjectURL(item.blob) : '')
    if (!src) return null
    return {
      type: 'image',
      ...common,
      fixedRatio: false,
      src,
      outline: outline(item),
      flipH: Boolean(item.isFlipH),
      flipV: Boolean(item.isFlipV),
    } as PPTElement
  }

  if (item.type === 'shape') {
    const isEllipse = /ellipse|oval|circle/i.test(String(item.shapType || ''))
    const text = item.content ? {
      content: item.content,
      defaultFontName: 'Arial',
      defaultColor: '#000000',
      align: item.vAlign === 'mid' ? 'middle' as const : 'top' as const,
    } : undefined
    return {
      type: 'shape',
      ...common,
      viewBox: [200, 200],
      path: isEllipse ? ELLIPSE_PATH : RECT_PATH,
      fixedRatio: false,
      fill: fillColor(item.fill),
      outline: outline(item),
      flipH: Boolean(item.isFlipH),
      flipV: Boolean(item.isFlipV),
      text,
    } as PPTElement
  }

  if (item.type === 'table') {
    const data = (item.data || []).map((row: any[], rowIndex: number) => row.map((cell: any, colIndex: number) => ({
      id: nanoid(8),
      colspan: Number(cell.colSpan || 1),
      rowspan: Number(cell.rowSpan || 1),
      text: cell.text || '',
      style: {
        color: cell.fontColor,
        backcolor: cell.fillColor,
        bold: Boolean(cell.fontBold),
        align: 'left' as const,
      },
    })))
    return {
      type: 'table',
      ...common,
      outline: { width: 1, color: '#999999', style: 'solid' },
      colWidths: data[0]?.map(() => 100 / Math.max(1, data[0].length)) || [],
      data,
    } as PPTElement
  }

  if (item.type === 'chart') {
    const chartType = /pie|doughnut/i.test(String(item.chartType)) ? 'pie' : /line/i.test(String(item.chartType)) ? 'line' : 'bar'
    const values = item.data || []
    const labels = Array.from(new Set(values.flatMap((series: any) => (series.values || []).map((v: any) => String(v.x)))))
    return {
      type: 'chart',
      ...common,
      chartType,
      themeColor: item.colors || ['#4472C4', '#ED7D31', '#A5A5A5'],
      data: {
        labels,
        legends: values.map((series: any) => String(series.key || 'Series')),
        series: values.map((series: any) => labels.map(label => Number(series.values?.find((v: any) => String(v.x) === label)?.y || 0))),
      },
    } as PPTElement
  }

  return null
}

export async function importPptx(buffer: ArrayBuffer): Promise<{ slides: Slide[]; width: number; height: number; themeColor: string }> {
  const parsed = await parse(buffer, { imageMode: 'base64', videoMode: 'none', audioMode: 'none' }) as ParsedPptx
  const sourceWidth = Number(parsed.size?.width || 960)
  const sourceHeight = Number(parsed.size?.height || 540)
  const scale = 960 / sourceWidth
  const slides: Slide[] = (parsed.slides || []).map((slide: any) => ({
    id: nanoid(10),
    remark: slide.note || '',
    background: slide.fill?.type === 'color'
      ? { type: 'solid' as const, color: fillColor(slide.fill, '#ffffff') }
      : undefined,
    elements: (slide.elements || [])
      .map((item: any, index: number) => elementFromParsed(item, scale, index))
      .filter(Boolean)
      .sort((a: any, b: any) => (a.order || 0) - (b.order || 0)) as PPTElement[],
  }))
  return {
    slides,
    width: 960,
    height: sourceHeight * scale,
    themeColor: color(parsed.themeColors?.[0], '#4472C4'),
  }
}
