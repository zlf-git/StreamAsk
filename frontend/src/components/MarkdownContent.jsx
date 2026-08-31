import React from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import ChartRenderer from './ChartRenderer'

// 解析 Dify 返回的结果，提取 result1 (Markdown) 和 result2 (图表)
const parseDifyResult = (content, rawOutputs = null) => {
  let markdown = content
  let chartConfig = null

  // 优先使用 rawOutputs
  if (rawOutputs) {
    if (rawOutputs.result1) {
      markdown = rawOutputs.result1
    }
    if (rawOutputs.result2) {
      try {
        if (typeof rawOutputs.result2 === 'string') {
          chartConfig = JSON.parse(rawOutputs.result2)
        } else {
          chartConfig = rawOutputs.result2
        }
      } catch (e) {
        console.error('Failed to parse chart config:', e)
      }
    }
    return { markdown, chartConfig }
  }

  // 兼容：尝试解析 content
  try {
    // 尝试解析 JSON
    const parsed = JSON.parse(content)

    // 如果是 Dify 返回的对象格式
    if (parsed.result1 || parsed.result2) {
      markdown = parsed.result1 || ''

      if (parsed.result2) {
        try {
          // result2 可能是字符串或对象
          if (typeof parsed.result2 === 'string') {
            chartConfig = JSON.parse(parsed.result2)
          } else {
            chartConfig = parsed.result2
          }
        } catch (e) {
          console.error('Failed to parse chart config:', e)
        }
      }
    }
  } catch (e) {
    // 不是 JSON 格式，保持原样
  }

  return { markdown, chartConfig }
}

const MarkdownContent = ({ content, rawOutputs }) => {
  const { markdown, chartConfig } = parseDifyResult(content, rawOutputs)

  // 检测 Markdown 中是否包含图表配置
  const chartPattern = /```chart\n([\s\S]*?)\n```/g
  const hasChart = chartPattern.test(markdown)

  // 优先使用 result2 的图表配置
  const finalChartConfig = chartConfig || (hasChart ? extractChartFromMarkdown(markdown) : null)

  // 如果有图表配置（来自 result2），渲染图表和 Markdown
  if (finalChartConfig) {
    return (
      <div className="markdown-content-wrapper">
        <div className="markdown-content">
          <ReactMarkdown remarkPlugins={[remarkGfm]}>
            {markdown}
          </ReactMarkdown>
        </div>
        <ChartRenderer config={finalChartConfig} />
      </div>
    )
  }

  // 检测 Markdown 内部嵌入的图表
  if (hasChart) {
    const parts = []
    let lastIndex = 0
    let match
    const regex = /```chart\n([\s\S]*?)\n```/g

    while ((match = regex.exec(markdown)) !== null) {
      if (match.index > lastIndex) {
        parts.push({ type: 'markdown', content: markdown.slice(lastIndex, match.index) })
      }

      try {
        const chartConfig = JSON.parse(match[1])
        parts.push({ type: 'chart', config: chartConfig })
      } catch (e) {
        parts.push({ type: 'markdown', content: match[0] })
      }

      lastIndex = match.index + match[0].length
    }

    if (lastIndex < markdown.length) {
      parts.push({ type: 'markdown', content: markdown.slice(lastIndex) })
    }

    return (
      <div className="markdown-content">
        {parts.map((part, index) => (
          part.type === 'chart' ? (
            <ChartRenderer key={index} config={part.config} />
          ) : (
            <ReactMarkdown key={index} remarkPlugins={[remarkGfm]}>
              {part.content}
            </ReactMarkdown>
          )
        ))}
      </div>
    )
  }

  return (
    <div className="markdown-content">
      <ReactMarkdown remarkPlugins={[remarkGfm]}>
        {markdown}
      </ReactMarkdown>
    </div>
  )
}

// 从 Markdown 中提取图表配置
const extractChartFromMarkdown = (content) => {
  const chartPattern = /```chart\n([\s\S]*?)\n```/g
  const match = chartPattern.exec(content)
  if (match) {
    try {
      return JSON.parse(match[1])
    } catch (e) {
      return null
    }
  }
  return null
}

export default MarkdownContent
