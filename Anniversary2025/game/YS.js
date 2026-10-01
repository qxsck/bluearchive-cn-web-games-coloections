window.gtag=window.gtag||function(){};
const YS = {
  Assets: {},
  webpSupport: false,
  isMobile: /Android|webOS|iPhone|iPod|BlackBerry/i.test(navigator.userAgent),
  shareTwitter(texts, hashTags) {
    const text = texts.join('%0A') + '%0A'
    const tags = hashTags.join(' ')
    const url = 'https://twitter.com/intent/tweet?text=' + text + encodeURIComponent(tags)
    window.open(url, '_blank')
  },
  assetsEmptyContainer: null,

  shareFacebook(url = window.location.href) {
    this.openWindow(
      'http://www.facebook.com/sharer.php?u=' + encodeURIComponent(url),
      'sharer',
      626,
      736
    )
  },

  async sleep(ms = 1000) {
    return new Promise((resolve) => {
      setTimeout(resolve, ms)
    })
  },
  async openWindow(url, name, iWidth, iHeight) {
    const iTop = (window.screen.availHeight - 30 - iHeight) / 2
    const iLeft = (window.screen.availWidth - 10 - iWidth) / 2

    window.open(
      url,
      name,
      'height=' +
        iHeight +
        ',innerHeight=' +
        iHeight +
        ',width=' +
        iWidth +
        ',innerWidth=' +
        iWidth +
        ',top=' +
        iTop +
        ',left=' +
        iLeft +
        ',status=no,toolbar=no,menubar=no,location=no,resizable=no,scrollbars=0,titlebar=no'
    )
  },
  assetsLoader(assetsModules, loadFn) {
    const assetsPath = Object.keys(assetsModules)
    const totalAssets = assetsPath.length
    const concurrency = 5
    let loadedCount = 0

    let completeCallback = () => {}
    let errorCallback = () => {}

    if (!this.assetsEmptyContainer) {
      this.assetsEmptyContainer = document.createElement('div')
      this.assetsEmptyContainer.style.display = 'none'
      document.body.appendChild(this.assetsEmptyContainer)
    }

    const that = {
      Assets: {},
      onProgress: (fn) => {
        const processQueue = async () => {
          while (assetsPath.length > 0) {
            const path = assetsPath.shift()
            const name = path.match(/([^/.]+)\.(jpg|png|gif|jpeg|webp)$/)?.[1] || path
            try {
              const imgModule = await assetsModules[path]()
              const assetUrl = imgModule.default

              const asset = await loadFn(assetUrl)

              this.Assets[name] = asset

              loadedCount++
              const progress = Math.floor((loadedCount / totalAssets) * 100)
              fn(progress)

              if (loadedCount >= totalAssets) {
                completeCallback()
              }
            } catch (err) {
              if (loadedCount >= totalAssets - 1) {
                errorCallback(err)
              }
            }
          }
        }
        const workers = Array(concurrency).fill(0).map(processQueue)
        Promise.allSettled(workers)
        return that
      },
      onComplete: (fn) => {
        completeCallback = fn
        return that
      },
      onError: (fn) => {
        errorCallback = fn
        return that
      }
    }
    return that
  },

  adjustRem() {
    const adjust = (windowWidth = window.innerWidth) => {
      const baseFontSize = 16
      const designWidthPc = 1920
      const html = document.documentElement
      const rootValue = (windowWidth / designWidthPc) * baseFontSize
      document.body.style.minWidth = ''
      html.style.fontSize = rootValue + 'px'
    }
    window.addEventListener('resize', () => {
      adjust()
    })
    adjust()
  },

  checkWebpSupport() {
    this.webpSupport = false
    try {
      this.webpSupport =
        document.createElement('canvas').toDataURL('image/webp').indexOf('data:image/webp') === 0
    } catch (err) {
      console.log('error checking webp support:', err)
    }
  },
  async init(config = {}) {
    this.config = config

    this.checkWebpSupport()

    if (this.config?.webp) {
      document.documentElement.setAttribute('data-webp', this.webpSupport ? 'true' : 'false')
    } else {
      document.documentElement.setAttribute('data-webp', 'false')
    }

    window.addEventListener('DOMContentLoaded', async () => {
      this.adjustRem()

      if (this.config.vconsole) {
        try {
          await this.loadVConsole()
        } catch (err) {
          console.log('error loading vConsole:', err)
        }
      }
      if (this.config.landscape) {
        this.forceLandscape()
      }
    })
  },

  async loadVConsole() {
    const script = document.createElement('script')
    script.src = `${this.config.BASE_URL}/vconsole.min.js`
    document.head.appendChild(script)
    script.onload = () => {
      // const searchParams = new URLSearchParams(window.location.search)
      // if (searchParams.has('vconsole')) {
      this.vconsole = new window.VConsole()
      // }
    }
    script.onerror = (error) => {
      console.error('Failed to load vConsole:', error)
    }
  },
  async forceLandscape() {
    const el = document.createElement('div')
    document.body.appendChild(el)

    el.innerHTML = `
      <img
        src="./horizontal.png"
        alt=""
      />
      <span>Please rotate the screen to continue</span>
    `
    this.landscape = el
    el.style.visibility = 'hidden'
    el.id = 'horizontal-wrapper'

    const style = document.createElement('style')
    style.textContent = `
        #horizontal-wrapper {
        position: fixed;
        left: 0;
        top: 0;
        width: 100vw;
        height: 100vh;
        z-index: 1001;
        display: flex;
        align-items: center;
        justify-content: center;
        text-align: center;
        flex-direction: column;
        background-color: white;
        visibility: hidden;
      }

      #horizontal-wrapper > img {
        width: 80px;
      }
      #horizontal-wrapper span {
        font-family:
          Helvetica Neue,
          Arial,
          sans-serif;
        font-size: 18px;
        margin-top: 22px;
        padding: 0;
      }
      `
    document.head.appendChild(style)

    const run = () => {
      if (window.innerWidth < window.innerHeight) {
        el.style.visibility = 'visible'
      } else {
        el.style.visibility = 'hidden'
      }
    }
    window.addEventListener('resize', () => {
      run()
    })
    run()
  }
}

if (window.YS) {
  console.log('已经存在YS对象，覆盖！')
}
window.YS = YS
