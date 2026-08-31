import React, { useEffect, useRef } from 'react'
import * as echarts from 'echarts'

// 前端统一配色 - 适合深色背景
const FRONTEND_COLORS = [
  '#667EEA', // 紫色（主色）
  '#38EF7D', // 绿色
  '#F093FB', // 粉色
  '#F5576C', // 红色
  '#4FACFE', // 蓝色
  '#00F2FE', // 青色
  '#FA709A', // 玫红
  '#FEE140', // 黄色
]

// 强制使用前端配色的配置
const applyFrontendColors = (config) => {
  if (!config) return {}

  // 强制设置颜色
  const newConfig = {
    ...config,
    color: FRONTEND_COLORS,
    backgroundColor: 'transparent'
  }

  // 处理 series 中的颜色
  if (newConfig.series) {
    newConfig.series = newConfig.series.map((s, index) => ({
      ...s,
      itemStyle: {
        ...s.itemStyle,
        color: FRONTEND_COLORS[index % FRONTEND_COLORS.length]
      },
      lineStyle: {
        ...s.lineStyle,
        color: FRONTEND_COLORS[index % FRONTEND_COLORS.length]
      }
    }))
  }

  // 统一样式
  newConfig.title = {
    textStyle: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
    subtextStyle: { color: 'rgba(255,255,255,0.65)' },
    ...config.title
  }

  newConfig.tooltip = {
    trigger: 'axis',
    backgroundColor: 'rgba(30,30,30,0.95)',
    borderColor: '#667EEA',
    borderWidth: 1,
    textStyle: { color: '#fff' },
    ...config.tooltip
  }

  newConfig.legend = {
    textStyle: { color: 'rgba(255,255,255,0.85)' },
    top: 10,
    ...config.legend
  }

  // x轴样式
  if (newConfig.xAxis) {
    const xAxisConfig = Array.isArray(newConfig.xAxis) ? newConfig.xAxis : [newConfig.xAxis]
    newConfig.xAxis = xAxisConfig.map(x => ({
      axisLine: { lineStyle: { color: 'rgba(255,255,255,0.2)' } },
      axisLabel: { color: 'rgba(255,255,255,0.65)' },
      splitLine: { lineStyle: { color: 'rgba(255,255,255,0.05)' } },
      ...x
    }))
  }

  // y轴样式
  if (newConfig.yAxis) {
    const yAxisConfig = Array.isArray(newConfig.yAxis) ? newConfig.yAxis : [newConfig.yAxis]
    newConfig.yAxis = yAxisConfig.map(y => ({
      axisLine: { lineStyle: { color: 'rgba(255,255,255,0.2)' } },
      axisLabel: { color: 'rgba(255,255,255,0.65)' },
      splitLine: { lineStyle: { color: 'rgba(255,255,255,0.05)' } },
      ...y
    }))
  }

  return newConfig
}

const ChartRenderer = ({ config }) => {
  const chartRef = useRef(null)
  const chartInstanceRef = useRef(null)

  useEffect(() => {
    if (!chartRef.current || !config) return

    if (chartInstanceRef.current) {
      chartInstanceRef.current.dispose()
    }

    const chart = echarts.init(chartRef.current)
    chartInstanceRef.current = chart

    // 强制使用前端配色
    const finalConfig = applyFrontendColors(config)
    chart.setOption(finalConfig)

    const handleResize = () => chart.resize()
    window.addEventListener('resize', handleResize)

    return () => {
      window.removeEventListener('resize', handleResize)
      chart.dispose()
    }
  }, [config])

  return (
    <div className="chart-container">
      <div ref={chartRef} style={{ width: '100%', height: config?.height || 400 }} />
    </div>
  )
}

export default ChartRenderer
