import React, { useState, useEffect, useRef } from 'react'
import MarkdownContent from './MarkdownContent'

function Typewriter({ content, onComplete, speed = 30, renderMarkdown = false, rawOutputs = null }) {
  const [displayedText, setDisplayedText] = useState('')
  const [isComplete, setIsComplete] = useState(false)
  const timeoutRef = useRef(null)

  useEffect(() => {
    setDisplayedText('')
    setIsComplete(false)

    let currentIndex = 0

    const typeNextChar = () => {
      if (currentIndex < content.length) {
        setDisplayedText(content.substring(0, currentIndex + 1))
        currentIndex++
        timeoutRef.current = setTimeout(typeNextChar, speed)
      } else {
        setIsComplete(true)
        if (onComplete) onComplete()
      }
    }

    // 延迟一点开始，让用户体验更好
    timeoutRef.current = setTimeout(typeNextChar, 300)

    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current)
      }
    }
  }, [content, speed, onComplete])

  if (renderMarkdown) {
    return (
      <div className="markdown-content-wrapper">
        <MarkdownContent content={displayedText} rawOutputs={rawOutputs} />
        {!isComplete && <span className="cursor">|</span>}
      </div>
    )
  }

  return (
    <span>
      {displayedText}
      {!isComplete && <span className="cursor">|</span>}
    </span>
  )
}

export default Typewriter
