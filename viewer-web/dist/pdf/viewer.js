var __typeError = (msg) => {
  throw TypeError(msg);
};
var __accessCheck = (obj, member, msg) => member.has(obj) || __typeError("Cannot " + msg);
var __privateGet = (obj, member, getter) => (__accessCheck(obj, member, "read from private field"), getter ? getter.call(obj) : member.get(obj));
var __privateAdd = (obj, member, value) => member.has(obj) ? __typeError("Cannot add the same private member more than once") : member instanceof WeakSet ? member.add(obj) : member.set(obj, value);
var __privateSet = (obj, member, value, setter) => (__accessCheck(obj, member, "write to private field"), setter ? setter.call(obj, value) : member.set(obj, value), value);
var __privateMethod = (obj, member, method) => (__accessCheck(obj, member, "access private method"), method);
(() => {
  "use strict";
  var __webpack_modules__ = [
    ,
    /* 1 */
    /***/
    ((__unused_webpack_module, exports) => {
      var _classList, _percent, _visible;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.animationStarted = exports.VERTICAL_PADDING = exports.UNKNOWN_SCALE = exports.TextLayerMode = exports.SpreadMode = exports.SidebarView = exports.ScrollMode = exports.SCROLLBAR_PADDING = exports.RenderingStates = exports.RendererType = exports.ProgressBar = exports.PresentationModeState = exports.OutputScale = exports.MIN_SCALE = exports.MAX_SCALE = exports.MAX_AUTO_SCALE = exports.DEFAULT_SCALE_VALUE = exports.DEFAULT_SCALE_DELTA = exports.DEFAULT_SCALE = exports.AutoPrintRegExp = void 0;
      exports.apiPageLayoutToViewerModes = apiPageLayoutToViewerModes;
      exports.apiPageModeToSidebarView = apiPageModeToSidebarView;
      exports.approximateFraction = approximateFraction;
      exports.backtrackBeforeAllVisibleElements = backtrackBeforeAllVisibleElements;
      exports.binarySearchFirstItem = binarySearchFirstItem;
      exports.docStyle = void 0;
      exports.getActiveOrFocusedElement = getActiveOrFocusedElement;
      exports.getPageSizeInches = getPageSizeInches;
      exports.getVisibleElements = getVisibleElements;
      exports.isPortraitOrientation = isPortraitOrientation;
      exports.isValidRotation = isValidRotation;
      exports.isValidScrollMode = isValidScrollMode;
      exports.isValidSpreadMode = isValidSpreadMode;
      exports.noContextMenuHandler = noContextMenuHandler;
      exports.normalizeWheelEventDelta = normalizeWheelEventDelta;
      exports.normalizeWheelEventDirection = normalizeWheelEventDirection;
      exports.parseQueryString = parseQueryString;
      exports.removeNullCharacters = removeNullCharacters;
      exports.roundToDivide = roundToDivide;
      exports.scrollIntoView = scrollIntoView;
      exports.watchScroll = watchScroll;
      const DEFAULT_SCALE_VALUE = "auto";
      exports.DEFAULT_SCALE_VALUE = DEFAULT_SCALE_VALUE;
      const DEFAULT_SCALE = 1;
      exports.DEFAULT_SCALE = DEFAULT_SCALE;
      const DEFAULT_SCALE_DELTA = 1.1;
      exports.DEFAULT_SCALE_DELTA = DEFAULT_SCALE_DELTA;
      const MIN_SCALE = 0.1;
      exports.MIN_SCALE = MIN_SCALE;
      const MAX_SCALE = 10;
      exports.MAX_SCALE = MAX_SCALE;
      const UNKNOWN_SCALE = 0;
      exports.UNKNOWN_SCALE = UNKNOWN_SCALE;
      const MAX_AUTO_SCALE = 1.25;
      exports.MAX_AUTO_SCALE = MAX_AUTO_SCALE;
      const SCROLLBAR_PADDING = 40;
      exports.SCROLLBAR_PADDING = SCROLLBAR_PADDING;
      const VERTICAL_PADDING = 5;
      exports.VERTICAL_PADDING = VERTICAL_PADDING;
      const RenderingStates = {
        INITIAL: 0,
        RUNNING: 1,
        PAUSED: 2,
        FINISHED: 3
      };
      exports.RenderingStates = RenderingStates;
      const PresentationModeState = {
        UNKNOWN: 0,
        NORMAL: 1,
        CHANGING: 2,
        FULLSCREEN: 3
      };
      exports.PresentationModeState = PresentationModeState;
      const SidebarView = {
        UNKNOWN: -1,
        NONE: 0,
        THUMBS: 1,
        OUTLINE: 2,
        ATTACHMENTS: 3,
        LAYERS: 4
      };
      exports.SidebarView = SidebarView;
      const RendererType = {
        CANVAS: "canvas",
        SVG: "svg"
      };
      exports.RendererType = RendererType;
      const TextLayerMode = {
        DISABLE: 0,
        ENABLE: 1,
        ENABLE_ENHANCE: 2
      };
      exports.TextLayerMode = TextLayerMode;
      const ScrollMode = {
        UNKNOWN: -1,
        VERTICAL: 0,
        HORIZONTAL: 1,
        WRAPPED: 2,
        PAGE: 3
      };
      exports.ScrollMode = ScrollMode;
      const SpreadMode = {
        UNKNOWN: -1,
        NONE: 0,
        ODD: 1,
        EVEN: 2
      };
      exports.SpreadMode = SpreadMode;
      const AutoPrintRegExp = /\bprint\s*\(/;
      exports.AutoPrintRegExp = AutoPrintRegExp;
      class OutputScale {
        constructor() {
          const pixelRatio = window.devicePixelRatio || 1;
          this.sx = pixelRatio;
          this.sy = pixelRatio;
        }
        get scaled() {
          return this.sx !== 1 || this.sy !== 1;
        }
      }
      exports.OutputScale = OutputScale;
      function scrollIntoView(element, spot, scrollMatches = false) {
        let parent2 = element.offsetParent;
        if (!parent2) {
          console.error("offsetParent is not set -- cannot scroll");
          return;
        }
        let offsetY = element.offsetTop + element.clientTop;
        let offsetX = element.offsetLeft + element.clientLeft;
        while (parent2.clientHeight === parent2.scrollHeight && parent2.clientWidth === parent2.scrollWidth || scrollMatches && (parent2.classList.contains("markedContent") || getComputedStyle(parent2).overflow === "hidden")) {
          offsetY += parent2.offsetTop;
          offsetX += parent2.offsetLeft;
          parent2 = parent2.offsetParent;
          if (!parent2) {
            return;
          }
        }
        if (spot) {
          if (spot.top !== void 0) {
            offsetY += spot.top;
          }
          if (spot.left !== void 0) {
            offsetX += spot.left;
            parent2.scrollLeft = offsetX;
          }
        }
        parent2.scrollTop = offsetY;
      }
      function watchScroll(viewAreaElement, callback) {
        const debounceScroll = function(evt) {
          if (rAF) {
            return;
          }
          rAF = window.requestAnimationFrame(function viewAreaElementScrolled() {
            rAF = null;
            const currentX = viewAreaElement.scrollLeft;
            const lastX = state.lastX;
            if (currentX !== lastX) {
              state.right = currentX > lastX;
            }
            state.lastX = currentX;
            const currentY = viewAreaElement.scrollTop;
            const lastY = state.lastY;
            if (currentY !== lastY) {
              state.down = currentY > lastY;
            }
            state.lastY = currentY;
            callback(state);
          });
        };
        const state = {
          right: true,
          down: true,
          lastX: viewAreaElement.scrollLeft,
          lastY: viewAreaElement.scrollTop,
          _eventHandler: debounceScroll
        };
        let rAF = null;
        viewAreaElement.addEventListener("scroll", debounceScroll, true);
        return state;
      }
      function parseQueryString(query) {
        const params = /* @__PURE__ */ new Map();
        for (const [key, value] of new URLSearchParams(query)) {
          params.set(key.toLowerCase(), value);
        }
        return params;
      }
      const NullCharactersRegExp = /\x00/g;
      const InvisibleCharactersRegExp = /[\x01-\x1F]/g;
      function removeNullCharacters(str, replaceInvisible = false) {
        if (typeof str !== "string") {
          console.error(`The argument must be a string.`);
          return str;
        }
        if (replaceInvisible) {
          str = str.replace(InvisibleCharactersRegExp, " ");
        }
        return str.replace(NullCharactersRegExp, "");
      }
      function binarySearchFirstItem(items, condition, start = 0) {
        let minIndex = start;
        let maxIndex = items.length - 1;
        if (maxIndex < 0 || !condition(items[maxIndex])) {
          return items.length;
        }
        if (condition(items[minIndex])) {
          return minIndex;
        }
        while (minIndex < maxIndex) {
          const currentIndex = minIndex + maxIndex >> 1;
          const currentItem = items[currentIndex];
          if (condition(currentItem)) {
            maxIndex = currentIndex;
          } else {
            minIndex = currentIndex + 1;
          }
        }
        return minIndex;
      }
      function approximateFraction(x) {
        if (Math.floor(x) === x) {
          return [x, 1];
        }
        const xinv = 1 / x;
        const limit = 8;
        if (xinv > limit) {
          return [1, limit];
        } else if (Math.floor(xinv) === xinv) {
          return [1, xinv];
        }
        const x_ = x > 1 ? xinv : x;
        let a = 0, b = 1, c = 1, d = 1;
        while (true) {
          const p = a + c, q = b + d;
          if (q > limit) {
            break;
          }
          if (x_ <= p / q) {
            c = p;
            d = q;
          } else {
            a = p;
            b = q;
          }
        }
        let result;
        if (x_ - a / b < c / d - x_) {
          result = x_ === x ? [a, b] : [b, a];
        } else {
          result = x_ === x ? [c, d] : [d, c];
        }
        return result;
      }
      function roundToDivide(x, div) {
        const r = x % div;
        return r === 0 ? x : Math.round(x - r + div);
      }
      function getPageSizeInches({
        view,
        userUnit,
        rotate
      }) {
        const [x1, y1, x2, y2] = view;
        const changeOrientation = rotate % 180 !== 0;
        const width = (x2 - x1) / 72 * userUnit;
        const height = (y2 - y1) / 72 * userUnit;
        return {
          width: changeOrientation ? height : width,
          height: changeOrientation ? width : height
        };
      }
      function backtrackBeforeAllVisibleElements(index, views, top) {
        if (index < 2) {
          return index;
        }
        let elt = views[index].div;
        let pageTop = elt.offsetTop + elt.clientTop;
        if (pageTop >= top) {
          elt = views[index - 1].div;
          pageTop = elt.offsetTop + elt.clientTop;
        }
        for (let i = index - 2; i >= 0; --i) {
          elt = views[i].div;
          if (elt.offsetTop + elt.clientTop + elt.clientHeight <= pageTop) {
            break;
          }
          index = i;
        }
        return index;
      }
      function getVisibleElements({
        scrollEl,
        views,
        sortByVisibility = false,
        horizontal = false,
        rtl = false
      }) {
        const top = scrollEl.scrollTop, bottom = top + scrollEl.clientHeight;
        const left = scrollEl.scrollLeft, right = left + scrollEl.clientWidth;
        function isElementBottomAfterViewTop(view) {
          const element = view.div;
          const elementBottom = element.offsetTop + element.clientTop + element.clientHeight;
          return elementBottom > top;
        }
        function isElementNextAfterViewHorizontally(view) {
          const element = view.div;
          const elementLeft = element.offsetLeft + element.clientLeft;
          const elementRight = elementLeft + element.clientWidth;
          return rtl ? elementLeft < right : elementRight > left;
        }
        const visible = [], ids = /* @__PURE__ */ new Set(), numViews = views.length;
        let firstVisibleElementInd = binarySearchFirstItem(views, horizontal ? isElementNextAfterViewHorizontally : isElementBottomAfterViewTop);
        if (firstVisibleElementInd > 0 && firstVisibleElementInd < numViews && !horizontal) {
          firstVisibleElementInd = backtrackBeforeAllVisibleElements(firstVisibleElementInd, views, top);
        }
        let lastEdge = horizontal ? right : -1;
        for (let i = firstVisibleElementInd; i < numViews; i++) {
          const view = views[i], element = view.div;
          const currentWidth = element.offsetLeft + element.clientLeft;
          const currentHeight = element.offsetTop + element.clientTop;
          const viewWidth = element.clientWidth, viewHeight = element.clientHeight;
          const viewRight = currentWidth + viewWidth;
          const viewBottom = currentHeight + viewHeight;
          if (lastEdge === -1) {
            if (viewBottom >= bottom) {
              lastEdge = viewBottom;
            }
          } else if ((horizontal ? currentWidth : currentHeight) > lastEdge) {
            break;
          }
          if (viewBottom <= top || currentHeight >= bottom || viewRight <= left || currentWidth >= right) {
            continue;
          }
          const hiddenHeight = Math.max(0, top - currentHeight) + Math.max(0, viewBottom - bottom);
          const hiddenWidth = Math.max(0, left - currentWidth) + Math.max(0, viewRight - right);
          const fractionHeight = (viewHeight - hiddenHeight) / viewHeight, fractionWidth = (viewWidth - hiddenWidth) / viewWidth;
          const percent = fractionHeight * fractionWidth * 100 | 0;
          visible.push({
            id: view.id,
            x: currentWidth,
            y: currentHeight,
            view,
            percent,
            widthPercent: fractionWidth * 100 | 0
          });
          ids.add(view.id);
        }
        const first = visible[0], last = visible.at(-1);
        if (sortByVisibility) {
          visible.sort(function(a, b) {
            const pc = a.percent - b.percent;
            if (Math.abs(pc) > 1e-3) {
              return -pc;
            }
            return a.id - b.id;
          });
        }
        return {
          first,
          last,
          views: visible,
          ids
        };
      }
      function noContextMenuHandler(evt) {
        evt.preventDefault();
      }
      function normalizeWheelEventDirection(evt) {
        let delta = Math.hypot(evt.deltaX, evt.deltaY);
        const angle = Math.atan2(evt.deltaY, evt.deltaX);
        if (-0.25 * Math.PI < angle && angle < 0.75 * Math.PI) {
          delta = -delta;
        }
        return delta;
      }
      function normalizeWheelEventDelta(evt) {
        let delta = normalizeWheelEventDirection(evt);
        const MOUSE_DOM_DELTA_PIXEL_MODE = 0;
        const MOUSE_DOM_DELTA_LINE_MODE = 1;
        const MOUSE_PIXELS_PER_LINE = 30;
        const MOUSE_LINES_PER_PAGE = 30;
        if (evt.deltaMode === MOUSE_DOM_DELTA_PIXEL_MODE) {
          delta /= MOUSE_PIXELS_PER_LINE * MOUSE_LINES_PER_PAGE;
        } else if (evt.deltaMode === MOUSE_DOM_DELTA_LINE_MODE) {
          delta /= MOUSE_LINES_PER_PAGE;
        }
        return delta;
      }
      function isValidRotation(angle) {
        return Number.isInteger(angle) && angle % 90 === 0;
      }
      function isValidScrollMode(mode) {
        return Number.isInteger(mode) && Object.values(ScrollMode).includes(mode) && mode !== ScrollMode.UNKNOWN;
      }
      function isValidSpreadMode(mode) {
        return Number.isInteger(mode) && Object.values(SpreadMode).includes(mode) && mode !== SpreadMode.UNKNOWN;
      }
      function isPortraitOrientation(size) {
        return size.width <= size.height;
      }
      const animationStarted = new Promise(function(resolve) {
        window.requestAnimationFrame(resolve);
      });
      exports.animationStarted = animationStarted;
      const docStyle = document.documentElement.style;
      exports.docStyle = docStyle;
      function clamp(v, min, max) {
        return Math.min(Math.max(v, min), max);
      }
      class ProgressBar {
        constructor(id) {
          __privateAdd(this, _classList, null);
          __privateAdd(this, _percent, 0);
          __privateAdd(this, _visible, true);
          if (arguments.length > 1) {
            throw new Error("ProgressBar no longer accepts any additional options, please use CSS rules to modify its appearance instead.");
          }
          const bar = document.getElementById(id);
          __privateSet(this, _classList, bar.classList);
        }
        get percent() {
          return __privateGet(this, _percent);
        }
        set percent(val) {
          __privateSet(this, _percent, clamp(val, 0, 100));
          if (isNaN(val)) {
            __privateGet(this, _classList).add("indeterminate");
            return;
          }
          __privateGet(this, _classList).remove("indeterminate");
          docStyle.setProperty("--progressBar-percent", `${__privateGet(this, _percent)}%`);
        }
        setWidth(viewer) {
          if (!viewer) {
            return;
          }
          const container = viewer.parentNode;
          const scrollbarWidth = container.offsetWidth - viewer.offsetWidth;
          if (scrollbarWidth > 0) {
            docStyle.setProperty("--progressBar-end-offset", `${scrollbarWidth}px`);
          }
        }
        hide() {
          if (!__privateGet(this, _visible)) {
            return;
          }
          __privateSet(this, _visible, false);
          __privateGet(this, _classList).add("hidden");
        }
        show() {
          if (__privateGet(this, _visible)) {
            return;
          }
          __privateSet(this, _visible, true);
          __privateGet(this, _classList).remove("hidden");
        }
      }
      _classList = new WeakMap();
      _percent = new WeakMap();
      _visible = new WeakMap();
      exports.ProgressBar = ProgressBar;
      function getActiveOrFocusedElement() {
        let curRoot = document;
        let curActiveOrFocused = curRoot.activeElement || curRoot.querySelector(":focus");
        while (curActiveOrFocused == null ? void 0 : curActiveOrFocused.shadowRoot) {
          curRoot = curActiveOrFocused.shadowRoot;
          curActiveOrFocused = curRoot.activeElement || curRoot.querySelector(":focus");
        }
        return curActiveOrFocused;
      }
      function apiPageLayoutToViewerModes(layout) {
        let scrollMode = ScrollMode.VERTICAL, spreadMode = SpreadMode.NONE;
        switch (layout) {
          case "SinglePage":
            scrollMode = ScrollMode.PAGE;
            break;
          case "OneColumn":
            break;
          case "TwoPageLeft":
            scrollMode = ScrollMode.PAGE;
          case "TwoColumnLeft":
            spreadMode = SpreadMode.ODD;
            break;
          case "TwoPageRight":
            scrollMode = ScrollMode.PAGE;
          case "TwoColumnRight":
            spreadMode = SpreadMode.EVEN;
            break;
        }
        return {
          scrollMode,
          spreadMode
        };
      }
      function apiPageModeToSidebarView(mode) {
        switch (mode) {
          case "UseNone":
            return SidebarView.NONE;
          case "UseThumbs":
            return SidebarView.THUMBS;
          case "UseOutlines":
            return SidebarView.OUTLINE;
          case "UseAttachments":
            return SidebarView.ATTACHMENTS;
          case "UseOC":
            return SidebarView.LAYERS;
        }
        return SidebarView.NONE;
      }
    }),
    /* 2 */
    /***/
    ((__unused_webpack_module, exports) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.compatibilityParams = exports.OptionKind = exports.AppOptions = void 0;
      const compatibilityParams = /* @__PURE__ */ Object.create(null);
      exports.compatibilityParams = compatibilityParams;
      {
        const userAgent = navigator.userAgent || "";
        const platform = navigator.platform || "";
        const maxTouchPoints = navigator.maxTouchPoints || 1;
        const isAndroid = /Android/.test(userAgent);
        const isIOS = /\b(iPad|iPhone|iPod)(?=;)/.test(userAgent) || platform === "MacIntel" && maxTouchPoints > 1;
        (function checkCanvasSizeLimitation() {
          if (isIOS || isAndroid) {
            compatibilityParams.maxCanvasPixels = 5242880;
          }
        })();
      }
      const OptionKind = {
        VIEWER: 2,
        API: 4,
        WORKER: 8,
        PREFERENCE: 128
      };
      exports.OptionKind = OptionKind;
      const defaultOptions = {
        annotationEditorMode: {
          value: -1,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        annotationMode: {
          value: 2,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        cursorToolOnLoad: {
          value: 0,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        defaultZoomValue: {
          value: "",
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        disableHistory: {
          value: false,
          kind: OptionKind.VIEWER
        },
        disablePageLabels: {
          value: false,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        enablePermissions: {
          value: false,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        enablePrintAutoRotate: {
          value: true,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        enableScripting: {
          value: true,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        externalLinkRel: {
          value: "noopener noreferrer nofollow",
          kind: OptionKind.VIEWER
        },
        externalLinkTarget: {
          value: 0,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        historyUpdateUrl: {
          value: false,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        ignoreDestinationZoom: {
          value: false,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        imageResourcesPath: {
          value: "./images/",
          kind: OptionKind.VIEWER
        },
        maxCanvasPixels: {
          value: 16777216,
          kind: OptionKind.VIEWER
        },
        forcePageColors: {
          value: false,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        pageColorsBackground: {
          value: "Canvas",
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        pageColorsForeground: {
          value: "CanvasText",
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        pdfBugEnabled: {
          value: false,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        printResolution: {
          value: 150,
          kind: OptionKind.VIEWER
        },
        sidebarViewOnLoad: {
          value: -1,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        scrollModeOnLoad: {
          value: -1,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        spreadModeOnLoad: {
          value: -1,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        textLayerMode: {
          value: 1,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        useOnlyCssZoom: {
          value: false,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        viewerCssTheme: {
          value: 0,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        viewOnLoad: {
          value: 0,
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        },
        cMapPacked: {
          value: true,
          kind: OptionKind.API
        },
        cMapUrl: {
          value: "cmaps/",
          kind: OptionKind.API
        },
        disableAutoFetch: {
          value: false,
          kind: OptionKind.API + OptionKind.PREFERENCE
        },
        disableFontFace: {
          value: false,
          kind: OptionKind.API + OptionKind.PREFERENCE
        },
        disableRange: {
          value: false,
          kind: OptionKind.API + OptionKind.PREFERENCE
        },
        disableStream: {
          value: false,
          kind: OptionKind.API + OptionKind.PREFERENCE
        },
        docBaseUrl: {
          value: "",
          kind: OptionKind.API
        },
        enableXfa: {
          value: true,
          kind: OptionKind.API + OptionKind.PREFERENCE
        },
        fontExtraProperties: {
          value: false,
          kind: OptionKind.API
        },
        isEvalSupported: {
          value: true,
          kind: OptionKind.API
        },
        maxImageSize: {
          value: -1,
          kind: OptionKind.API
        },
        pdfBug: {
          value: false,
          kind: OptionKind.API
        },
        standardFontDataUrl: {
          value: "standard_fonts/",
          kind: OptionKind.API
        },
        verbosity: {
          value: 1,
          kind: OptionKind.API
        },
        workerPort: {
          value: null,
          kind: OptionKind.WORKER
        },
        workerSrc: {
          value: "pdf.worker.js?v=2.16.105-qt5.1",
          kind: OptionKind.WORKER
        }
      };
      {
        defaultOptions.defaultUrl = {
          value: "compressed.tracemonkey-pldi-09.pdf",
          kind: OptionKind.VIEWER
        };
        defaultOptions.disablePreferences = {
          value: false,
          kind: OptionKind.VIEWER
        };
        defaultOptions.locale = {
          value: navigator.language || "en-US",
          kind: OptionKind.VIEWER
        };
        defaultOptions.renderer = {
          value: "canvas",
          kind: OptionKind.VIEWER + OptionKind.PREFERENCE
        };
        defaultOptions.sandboxBundleSrc = {
          value: "../build/pdf.sandbox.js",
          kind: OptionKind.VIEWER
        };
      }
      const userOptions = /* @__PURE__ */ Object.create(null);
      class AppOptions {
        constructor() {
          throw new Error("Cannot initialize AppOptions.");
        }
        static get(name) {
          const userOption = userOptions[name];
          if (userOption !== void 0) {
            return userOption;
          }
          const defaultOption = defaultOptions[name];
          if (defaultOption !== void 0) {
            return compatibilityParams[name] ?? defaultOption.value;
          }
          return void 0;
        }
        static getAll(kind = null) {
          const options = /* @__PURE__ */ Object.create(null);
          for (const name in defaultOptions) {
            const defaultOption = defaultOptions[name];
            if (kind) {
              if ((kind & defaultOption.kind) === 0) {
                continue;
              }
              if (kind === OptionKind.PREFERENCE) {
                const value = defaultOption.value, valueType = typeof value;
                if (valueType === "boolean" || valueType === "string" || valueType === "number" && Number.isInteger(value)) {
                  options[name] = value;
                  continue;
                }
                throw new Error(`Invalid type for preference: ${name}`);
              }
            }
            const userOption = userOptions[name];
            options[name] = userOption !== void 0 ? userOption : compatibilityParams[name] ?? defaultOption.value;
          }
          return options;
        }
        static set(name, value) {
          userOptions[name] = value;
        }
        static setAll(options) {
          for (const name in options) {
            userOptions[name] = options[name];
          }
        }
        static remove(name) {
          delete userOptions[name];
        }
        static _hasUserOptions() {
          return Object.keys(userOptions).length > 0;
        }
      }
      exports.AppOptions = AppOptions;
    }),
    /* 3 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _pagesRefCache, _PDFLinkService_instances, goToDestinationHelper_fn, _PDFLinkService_static, isValidExplicitDestination_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.SimpleLinkService = exports.PDFLinkService = exports.LinkTarget = void 0;
      var _ui_utils = __webpack_require__2(1);
      const DEFAULT_LINK_REL = "noopener noreferrer nofollow";
      const LinkTarget = {
        NONE: 0,
        SELF: 1,
        BLANK: 2,
        PARENT: 3,
        TOP: 4
      };
      exports.LinkTarget = LinkTarget;
      function addLinkAttributes(link, {
        url,
        target,
        rel,
        enabled = true
      } = {}) {
        if (!url || typeof url !== "string") {
          throw new Error('A valid "url" parameter must provided.');
        }
        const urlNullRemoved = (0, _ui_utils.removeNullCharacters)(url);
        if (enabled) {
          link.href = link.title = urlNullRemoved;
        } else {
          link.href = "";
          link.title = `Disabled: ${urlNullRemoved}`;
          link.onclick = () => {
            return false;
          };
        }
        let targetStr = "";
        switch (target) {
          case LinkTarget.NONE:
            break;
          case LinkTarget.SELF:
            targetStr = "_self";
            break;
          case LinkTarget.BLANK:
            targetStr = "_blank";
            break;
          case LinkTarget.PARENT:
            targetStr = "_parent";
            break;
          case LinkTarget.TOP:
            targetStr = "_top";
            break;
        }
        link.target = targetStr;
        link.rel = typeof rel === "string" ? rel : DEFAULT_LINK_REL;
      }
      const _PDFLinkService = class _PDFLinkService {
        constructor({
          eventBus,
          externalLinkTarget = null,
          externalLinkRel = null,
          ignoreDestinationZoom = false
        } = {}) {
          __privateAdd(this, _PDFLinkService_instances);
          __privateAdd(this, _pagesRefCache, /* @__PURE__ */ new Map());
          this.eventBus = eventBus;
          this.externalLinkTarget = externalLinkTarget;
          this.externalLinkRel = externalLinkRel;
          this.externalLinkEnabled = true;
          this._ignoreDestinationZoom = ignoreDestinationZoom;
          this.baseUrl = null;
          this.pdfDocument = null;
          this.pdfViewer = null;
          this.pdfHistory = null;
        }
        setDocument(pdfDocument, baseUrl = null) {
          this.baseUrl = baseUrl;
          this.pdfDocument = pdfDocument;
          __privateGet(this, _pagesRefCache).clear();
        }
        setViewer(pdfViewer) {
          this.pdfViewer = pdfViewer;
        }
        setHistory(pdfHistory) {
          this.pdfHistory = pdfHistory;
        }
        get pagesCount() {
          return this.pdfDocument ? this.pdfDocument.numPages : 0;
        }
        get page() {
          return this.pdfViewer.currentPageNumber;
        }
        set page(value) {
          this.pdfViewer.currentPageNumber = value;
        }
        get rotation() {
          return this.pdfViewer.pagesRotation;
        }
        set rotation(value) {
          this.pdfViewer.pagesRotation = value;
        }
        async goToDestination(dest) {
          if (!this.pdfDocument) {
            return;
          }
          let namedDest, explicitDest;
          if (typeof dest === "string") {
            namedDest = dest;
            explicitDest = await this.pdfDocument.getDestination(dest);
          } else {
            namedDest = null;
            explicitDest = await dest;
          }
          if (!Array.isArray(explicitDest)) {
            console.error(`PDFLinkService.goToDestination: "${explicitDest}" is not a valid destination array, for dest="${dest}".`);
            return;
          }
          __privateMethod(this, _PDFLinkService_instances, goToDestinationHelper_fn).call(this, dest, namedDest, explicitDest);
        }
        goToPage(val) {
          if (!this.pdfDocument) {
            return;
          }
          const pageNumber = typeof val === "string" && this.pdfViewer.pageLabelToPageNumber(val) || val | 0;
          if (!(Number.isInteger(pageNumber) && pageNumber > 0 && pageNumber <= this.pagesCount)) {
            console.error(`PDFLinkService.goToPage: "${val}" is not a valid page.`);
            return;
          }
          if (this.pdfHistory) {
            this.pdfHistory.pushCurrentPosition();
            this.pdfHistory.pushPage(pageNumber);
          }
          this.pdfViewer.scrollPageIntoView({
            pageNumber
          });
        }
        addLinkAttributes(link, url, newWindow = false) {
          addLinkAttributes(link, {
            url,
            target: newWindow ? LinkTarget.BLANK : this.externalLinkTarget,
            rel: this.externalLinkRel,
            enabled: this.externalLinkEnabled
          });
        }
        getDestinationHash(dest) {
          if (typeof dest === "string") {
            if (dest.length > 0) {
              return this.getAnchorUrl("#" + escape(dest));
            }
          } else if (Array.isArray(dest)) {
            const str = JSON.stringify(dest);
            if (str.length > 0) {
              return this.getAnchorUrl("#" + escape(str));
            }
          }
          return this.getAnchorUrl("");
        }
        getAnchorUrl(anchor) {
          return (this.baseUrl || "") + anchor;
        }
        setHash(hash) {
          var _a;
          if (!this.pdfDocument) {
            return;
          }
          let pageNumber, dest;
          if (hash.includes("=")) {
            const params = (0, _ui_utils.parseQueryString)(hash);
            if (params.has("search")) {
              this.eventBus.dispatch("findfromurlhash", {
                source: this,
                query: params.get("search").replace(/"/g, ""),
                phraseSearch: params.get("phrase") === "true"
              });
            }
            if (params.has("page")) {
              pageNumber = params.get("page") | 0 || 1;
            }
            if (params.has("zoom")) {
              const zoomArgs = params.get("zoom").split(",");
              const zoomArg = zoomArgs[0];
              const zoomArgNumber = parseFloat(zoomArg);
              if (!zoomArg.includes("Fit")) {
                dest = [null, {
                  name: "XYZ"
                }, zoomArgs.length > 1 ? zoomArgs[1] | 0 : null, zoomArgs.length > 2 ? zoomArgs[2] | 0 : null, zoomArgNumber ? zoomArgNumber / 100 : zoomArg];
              } else {
                if (zoomArg === "Fit" || zoomArg === "FitB") {
                  dest = [null, {
                    name: zoomArg
                  }];
                } else if (zoomArg === "FitH" || zoomArg === "FitBH" || zoomArg === "FitV" || zoomArg === "FitBV") {
                  dest = [null, {
                    name: zoomArg
                  }, zoomArgs.length > 1 ? zoomArgs[1] | 0 : null];
                } else if (zoomArg === "FitR") {
                  if (zoomArgs.length !== 5) {
                    console.error('PDFLinkService.setHash: Not enough parameters for "FitR".');
                  } else {
                    dest = [null, {
                      name: zoomArg
                    }, zoomArgs[1] | 0, zoomArgs[2] | 0, zoomArgs[3] | 0, zoomArgs[4] | 0];
                  }
                } else {
                  console.error(`PDFLinkService.setHash: "${zoomArg}" is not a valid zoom value.`);
                }
              }
            }
            if (dest) {
              this.pdfViewer.scrollPageIntoView({
                pageNumber: pageNumber || this.page,
                destArray: dest,
                allowNegativeOffset: true
              });
            } else if (pageNumber) {
              this.page = pageNumber;
            }
            if (params.has("pagemode")) {
              this.eventBus.dispatch("pagemode", {
                source: this,
                mode: params.get("pagemode")
              });
            }
            if (params.has("nameddest")) {
              this.goToDestination(params.get("nameddest"));
            }
          } else {
            dest = unescape(hash);
            try {
              dest = JSON.parse(dest);
              if (!Array.isArray(dest)) {
                dest = dest.toString();
              }
            } catch (ex) {
            }
            if (typeof dest === "string" || __privateMethod(_a = _PDFLinkService, _PDFLinkService_static, isValidExplicitDestination_fn).call(_a, dest)) {
              this.goToDestination(dest);
              return;
            }
            console.error(`PDFLinkService.setHash: "${unescape(hash)}" is not a valid destination.`);
          }
        }
        executeNamedAction(action) {
          var _a, _b;
          switch (action) {
            case "GoBack":
              (_a = this.pdfHistory) == null ? void 0 : _a.back();
              break;
            case "GoForward":
              (_b = this.pdfHistory) == null ? void 0 : _b.forward();
              break;
            case "NextPage":
              this.pdfViewer.nextPage();
              break;
            case "PrevPage":
              this.pdfViewer.previousPage();
              break;
            case "LastPage":
              this.page = this.pagesCount;
              break;
            case "FirstPage":
              this.page = 1;
              break;
            default:
              break;
          }
          this.eventBus.dispatch("namedaction", {
            source: this,
            action
          });
        }
        cachePageRef(pageNum, pageRef) {
          if (!pageRef) {
            return;
          }
          const refStr = pageRef.gen === 0 ? `${pageRef.num}R` : `${pageRef.num}R${pageRef.gen}`;
          __privateGet(this, _pagesRefCache).set(refStr, pageNum);
        }
        _cachedPageNumber(pageRef) {
          if (!pageRef) {
            return null;
          }
          const refStr = pageRef.gen === 0 ? `${pageRef.num}R` : `${pageRef.num}R${pageRef.gen}`;
          return __privateGet(this, _pagesRefCache).get(refStr) || null;
        }
        isPageVisible(pageNumber) {
          return this.pdfViewer.isPageVisible(pageNumber);
        }
        isPageCached(pageNumber) {
          return this.pdfViewer.isPageCached(pageNumber);
        }
      };
      _pagesRefCache = new WeakMap();
      _PDFLinkService_instances = new WeakSet();
      goToDestinationHelper_fn = function(rawDest, namedDest = null, explicitDest) {
        const destRef = explicitDest[0];
        let pageNumber;
        if (typeof destRef === "object" && destRef !== null) {
          pageNumber = this._cachedPageNumber(destRef);
          if (!pageNumber) {
            this.pdfDocument.getPageIndex(destRef).then((pageIndex) => {
              this.cachePageRef(pageIndex + 1, destRef);
              __privateMethod(this, _PDFLinkService_instances, goToDestinationHelper_fn).call(this, rawDest, namedDest, explicitDest);
            }).catch(() => {
              console.error(`PDFLinkService.#goToDestinationHelper: "${destRef}" is not a valid page reference, for dest="${rawDest}".`);
            });
            return;
          }
        } else if (Number.isInteger(destRef)) {
          pageNumber = destRef + 1;
        } else {
          console.error(`PDFLinkService.#goToDestinationHelper: "${destRef}" is not a valid destination reference, for dest="${rawDest}".`);
          return;
        }
        if (!pageNumber || pageNumber < 1 || pageNumber > this.pagesCount) {
          console.error(`PDFLinkService.#goToDestinationHelper: "${pageNumber}" is not a valid page number, for dest="${rawDest}".`);
          return;
        }
        if (this.pdfHistory) {
          this.pdfHistory.pushCurrentPosition();
          this.pdfHistory.push({
            namedDest,
            explicitDest,
            pageNumber
          });
        }
        this.pdfViewer.scrollPageIntoView({
          pageNumber,
          destArray: explicitDest,
          ignoreDestinationZoom: this._ignoreDestinationZoom
        });
      };
      _PDFLinkService_static = new WeakSet();
      isValidExplicitDestination_fn = function(dest) {
        if (!Array.isArray(dest)) {
          return false;
        }
        const destLength = dest.length;
        if (destLength < 2) {
          return false;
        }
        const page = dest[0];
        if (!(typeof page === "object" && Number.isInteger(page.num) && Number.isInteger(page.gen)) && !(Number.isInteger(page) && page >= 0)) {
          return false;
        }
        const zoom = dest[1];
        if (!(typeof zoom === "object" && typeof zoom.name === "string")) {
          return false;
        }
        let allowNull = true;
        switch (zoom.name) {
          case "XYZ":
            if (destLength !== 5) {
              return false;
            }
            break;
          case "Fit":
          case "FitB":
            return destLength === 2;
          case "FitH":
          case "FitBH":
          case "FitV":
          case "FitBV":
            if (destLength !== 3) {
              return false;
            }
            break;
          case "FitR":
            if (destLength !== 6) {
              return false;
            }
            allowNull = false;
            break;
          default:
            return false;
        }
        for (let i = 2; i < destLength; i++) {
          const param = dest[i];
          if (!(typeof param === "number" || allowNull && param === null)) {
            return false;
          }
        }
        return true;
      };
      __privateAdd(_PDFLinkService, _PDFLinkService_static);
      let PDFLinkService = _PDFLinkService;
      exports.PDFLinkService = PDFLinkService;
      class SimpleLinkService {
        constructor() {
          this.externalLinkEnabled = true;
        }
        get pagesCount() {
          return 0;
        }
        get page() {
          return 0;
        }
        set page(value) {
        }
        get rotation() {
          return 0;
        }
        set rotation(value) {
        }
        async goToDestination(dest) {
        }
        goToPage(val) {
        }
        addLinkAttributes(link, url, newWindow = false) {
          addLinkAttributes(link, {
            url,
            enabled: this.externalLinkEnabled
          });
        }
        getDestinationHash(dest) {
          return "#";
        }
        getAnchorUrl(hash) {
          return "#";
        }
        setHash(hash) {
        }
        executeNamedAction(action) {
        }
        cachePageRef(pageNum, pageRef) {
        }
        isPageVisible(pageNumber) {
          return true;
        }
        isPageCached(pageNumber) {
          return true;
        }
      }
      exports.SimpleLinkService = SimpleLinkService;
    }),
    /* 4 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFViewerApplication = exports.PDFPrintServiceFactory = exports.DefaultExternalServices = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _pdfjsLib = __webpack_require__2(5);
      var _app_options = __webpack_require__2(2);
      var _event_utils = __webpack_require__2(6);
      var _pdf_cursor_tools = __webpack_require__2(7);
      var _pdf_link_service = __webpack_require__2(3);
      var _annotation_editor_params = __webpack_require__2(9);
      var _overlay_manager = __webpack_require__2(10);
      var _password_prompt = __webpack_require__2(11);
      var _pdf_attachment_viewer = __webpack_require__2(12);
      var _pdf_document_properties = __webpack_require__2(14);
      var _pdf_find_bar = __webpack_require__2(15);
      var _pdf_find_controller = __webpack_require__2(16);
      var _pdf_history = __webpack_require__2(18);
      var _pdf_layer_viewer = __webpack_require__2(19);
      var _pdf_outline_viewer = __webpack_require__2(20);
      var _pdf_presentation_mode = __webpack_require__2(21);
      var _pdf_rendering_queue = __webpack_require__2(22);
      var _pdf_scripting_manager = __webpack_require__2(23);
      var _pdf_sidebar = __webpack_require__2(24);
      var _pdf_sidebar_resizer = __webpack_require__2(25);
      var _pdf_thumbnail_viewer = __webpack_require__2(26);
      var _pdf_viewer = __webpack_require__2(28);
      var _secondary_toolbar = __webpack_require__2(39);
      var _toolbar = __webpack_require__2(40);
      var _view_history = __webpack_require__2(41);
      const DISABLE_AUTO_FETCH_LOADING_BAR_TIMEOUT = 5e3;
      const FORCE_PAGES_LOADED_TIMEOUT = 1e4;
      const WHEEL_ZOOM_DISABLED_TIMEOUT = 1e3;
      const ViewOnLoad = {
        UNKNOWN: -1,
        PREVIOUS: 0,
        INITIAL: 1
      };
      const ViewerCssTheme = {
        AUTOMATIC: 0,
        LIGHT: 1,
        DARK: 2
      };
      const KNOWN_VERSIONS = ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "2.0", "2.1", "2.2", "2.3"];
      const KNOWN_GENERATORS = ["acrobat distiller", "acrobat pdfwriter", "adobe livecycle", "adobe pdf library", "adobe photoshop", "ghostscript", "tcpdf", "cairo", "dvipdfm", "dvips", "pdftex", "pdfkit", "itext", "prince", "quarkxpress", "mac os x", "microsoft", "openoffice", "oracle", "luradocument", "pdf-xchange", "antenna house", "aspose.cells", "fpdf"];
      class DefaultExternalServices {
        constructor() {
          throw new Error("Cannot initialize DefaultExternalServices.");
        }
        static updateFindControlState(data) {
        }
        static updateFindMatchesCount(data) {
        }
        static initPassiveLoading(callbacks) {
        }
        static reportTelemetry(data) {
        }
        static createDownloadManager(options) {
          throw new Error("Not implemented: createDownloadManager");
        }
        static createPreferences() {
          throw new Error("Not implemented: createPreferences");
        }
        static createL10n(options) {
          throw new Error("Not implemented: createL10n");
        }
        static createScripting(options) {
          throw new Error("Not implemented: createScripting");
        }
        static get supportsIntegratedFind() {
          return (0, _pdfjsLib.shadow)(this, "supportsIntegratedFind", false);
        }
        static get supportsDocumentFonts() {
          return (0, _pdfjsLib.shadow)(this, "supportsDocumentFonts", true);
        }
        static get supportedMouseWheelZoomModifierKeys() {
          return (0, _pdfjsLib.shadow)(this, "supportedMouseWheelZoomModifierKeys", {
            ctrlKey: true,
            metaKey: true
          });
        }
        static get isInAutomation() {
          return (0, _pdfjsLib.shadow)(this, "isInAutomation", false);
        }
        static updateEditorStates(data) {
          throw new Error("Not implemented: updateEditorStates");
        }
      }
      exports.DefaultExternalServices = DefaultExternalServices;
      const PDFViewerApplication = {
        initialBookmark: document.location.hash.substring(1),
        _initializedCapability: (0, _pdfjsLib.createPromiseCapability)(),
        appConfig: null,
        pdfDocument: null,
        pdfLoadingTask: null,
        printService: null,
        pdfViewer: null,
        pdfThumbnailViewer: null,
        pdfRenderingQueue: null,
        pdfPresentationMode: null,
        pdfDocumentProperties: null,
        pdfLinkService: null,
        pdfHistory: null,
        pdfSidebar: null,
        pdfSidebarResizer: null,
        pdfOutlineViewer: null,
        pdfAttachmentViewer: null,
        pdfLayerViewer: null,
        pdfCursorTools: null,
        pdfScriptingManager: null,
        store: null,
        downloadManager: null,
        overlayManager: null,
        preferences: null,
        toolbar: null,
        secondaryToolbar: null,
        eventBus: null,
        l10n: null,
        annotationEditorParams: null,
        isInitialViewSet: false,
        downloadComplete: false,
        isViewerEmbedded: window.parent !== window,
        url: "",
        baseUrl: "",
        _downloadUrl: "",
        externalServices: DefaultExternalServices,
        _boundEvents: /* @__PURE__ */ Object.create(null),
        documentInfo: null,
        metadata: null,
        _contentDispositionFilename: null,
        _contentLength: null,
        _saveInProgress: false,
        _docStats: null,
        _wheelUnusedTicks: 0,
        _idleCallbacks: /* @__PURE__ */ new Set(),
        _PDFBug: null,
        _hasAnnotationEditors: false,
        _title: document.title,
        _printAnnotationStoragePromise: null,
        async initialize(appConfig) {
          this.preferences = this.externalServices.createPreferences();
          this.appConfig = appConfig;
          await this._readPreferences();
          await this._parseHashParameters();
          this._forceCssTheme();
          await this._initializeL10n();
          if (this.isViewerEmbedded && _app_options.AppOptions.get("externalLinkTarget") === _pdf_link_service.LinkTarget.NONE) {
            _app_options.AppOptions.set("externalLinkTarget", _pdf_link_service.LinkTarget.TOP);
          }
          await this._initializeViewerComponents();
          this.bindEvents();
          this.bindWindowEvents();
          const appContainer = appConfig.appContainer || document.documentElement;
          this.l10n.translate(appContainer).then(() => {
            this.eventBus.dispatch("localized", {
              source: this
            });
          });
          this._initializedCapability.resolve();
        },
        async _readPreferences() {
          if (_app_options.AppOptions.get("disablePreferences")) {
            return;
          }
          if (_app_options.AppOptions._hasUserOptions()) {
            console.warn('_readPreferences: The Preferences may override manually set AppOptions; please use the "disablePreferences"-option in order to prevent that.');
          }
          try {
            _app_options.AppOptions.setAll(await this.preferences.getAll());
          } catch (reason) {
            console.error(`_readPreferences: "${reason == null ? void 0 : reason.message}".`);
          }
        },
        async _parseHashParameters() {
          if (!_app_options.AppOptions.get("pdfBugEnabled")) {
            return;
          }
          const hash = document.location.hash.substring(1);
          if (!hash) {
            return;
          }
          const {
            mainContainer,
            viewerContainer
          } = this.appConfig, params = (0, _ui_utils.parseQueryString)(hash);
          if (params.get("disableworker") === "true") {
            try {
              await loadFakeWorker();
            } catch (ex) {
              console.error(`_parseHashParameters: "${ex.message}".`);
            }
          }
          if (params.has("disablerange")) {
            _app_options.AppOptions.set("disableRange", params.get("disablerange") === "true");
          }
          if (params.has("disablestream")) {
            _app_options.AppOptions.set("disableStream", params.get("disablestream") === "true");
          }
          if (params.has("disableautofetch")) {
            _app_options.AppOptions.set("disableAutoFetch", params.get("disableautofetch") === "true");
          }
          if (params.has("disablefontface")) {
            _app_options.AppOptions.set("disableFontFace", params.get("disablefontface") === "true");
          }
          if (params.has("disablehistory")) {
            _app_options.AppOptions.set("disableHistory", params.get("disablehistory") === "true");
          }
          if (params.has("verbosity")) {
            _app_options.AppOptions.set("verbosity", params.get("verbosity") | 0);
          }
          if (params.has("textlayer")) {
            switch (params.get("textlayer")) {
              case "off":
                _app_options.AppOptions.set("textLayerMode", _ui_utils.TextLayerMode.DISABLE);
                break;
              case "visible":
              case "shadow":
              case "hover":
                viewerContainer.classList.add(`textLayer-${params.get("textlayer")}`);
                try {
                  await loadPDFBug(this);
                  this._PDFBug.loadCSS();
                } catch (ex) {
                  console.error(`_parseHashParameters: "${ex.message}".`);
                }
                break;
            }
          }
          if (params.has("pdfbug")) {
            _app_options.AppOptions.set("pdfBug", true);
            _app_options.AppOptions.set("fontExtraProperties", true);
            const enabled = params.get("pdfbug").split(",");
            try {
              await loadPDFBug(this);
              this._PDFBug.init({
                OPS: _pdfjsLib.OPS
              }, mainContainer, enabled);
            } catch (ex) {
              console.error(`_parseHashParameters: "${ex.message}".`);
            }
          }
          if (params.has("locale")) {
            _app_options.AppOptions.set("locale", params.get("locale"));
          }
        },
        async _initializeL10n() {
          this.l10n = this.externalServices.createL10n({
            locale: _app_options.AppOptions.get("locale")
          });
          const dir = await this.l10n.getDirection();
          document.getElementsByTagName("html")[0].dir = dir;
        },
        _forceCssTheme() {
          var _a;
          const cssTheme = _app_options.AppOptions.get("viewerCssTheme");
          if (cssTheme === ViewerCssTheme.AUTOMATIC || !Object.values(ViewerCssTheme).includes(cssTheme)) {
            return;
          }
          try {
            const styleSheet = document.styleSheets[0];
            const cssRules = (styleSheet == null ? void 0 : styleSheet.cssRules) || [];
            for (let i = 0, ii = cssRules.length; i < ii; i++) {
              const rule = cssRules[i];
              if (rule instanceof CSSMediaRule && ((_a = rule.media) == null ? void 0 : _a[0]) === "(prefers-color-scheme: dark)") {
                if (cssTheme === ViewerCssTheme.LIGHT) {
                  styleSheet.deleteRule(i);
                  return;
                }
                const darkRules = /^@media \(prefers-color-scheme: dark\) {\n\s*([\w\s-.,:;/\\{}()]+)\n}$/.exec(rule.cssText);
                if (darkRules == null ? void 0 : darkRules[1]) {
                  styleSheet.deleteRule(i);
                  styleSheet.insertRule(darkRules[1], i);
                }
                return;
              }
            }
          } catch (reason) {
            console.error(`_forceCssTheme: "${reason == null ? void 0 : reason.message}".`);
          }
        },
        async _initializeViewerComponents() {
          const {
            appConfig,
            externalServices
          } = this;
          const eventBus = externalServices.isInAutomation ? new _event_utils.AutomationEventBus() : new _event_utils.EventBus();
          this.eventBus = eventBus;
          this.overlayManager = new _overlay_manager.OverlayManager();
          const pdfRenderingQueue = new _pdf_rendering_queue.PDFRenderingQueue();
          pdfRenderingQueue.onIdle = this._cleanup.bind(this);
          this.pdfRenderingQueue = pdfRenderingQueue;
          const pdfLinkService = new _pdf_link_service.PDFLinkService({
            eventBus,
            externalLinkTarget: _app_options.AppOptions.get("externalLinkTarget"),
            externalLinkRel: _app_options.AppOptions.get("externalLinkRel"),
            ignoreDestinationZoom: _app_options.AppOptions.get("ignoreDestinationZoom")
          });
          this.pdfLinkService = pdfLinkService;
          const downloadManager = externalServices.createDownloadManager();
          this.downloadManager = downloadManager;
          const findController = new _pdf_find_controller.PDFFindController({
            linkService: pdfLinkService,
            eventBus
          });
          this.findController = findController;
          const pdfScriptingManager = new _pdf_scripting_manager.PDFScriptingManager({
            eventBus,
            sandboxBundleSrc: _app_options.AppOptions.get("sandboxBundleSrc"),
            scriptingFactory: externalServices,
            docPropertiesLookup: this._scriptingDocProperties.bind(this)
          });
          this.pdfScriptingManager = pdfScriptingManager;
          const container = appConfig.mainContainer, viewer = appConfig.viewerContainer;
          const annotationEditorMode = _app_options.AppOptions.get("annotationEditorMode");
          const pageColors = _app_options.AppOptions.get("forcePageColors") || window.matchMedia("(forced-colors: active)").matches ? {
            background: _app_options.AppOptions.get("pageColorsBackground"),
            foreground: _app_options.AppOptions.get("pageColorsForeground")
          } : null;
          this.pdfViewer = new _pdf_viewer.PDFViewer({
            container,
            viewer,
            eventBus,
            renderingQueue: pdfRenderingQueue,
            linkService: pdfLinkService,
            downloadManager,
            findController,
            scriptingManager: _app_options.AppOptions.get("enableScripting") && pdfScriptingManager,
            renderer: _app_options.AppOptions.get("renderer"),
            l10n: this.l10n,
            textLayerMode: _app_options.AppOptions.get("textLayerMode"),
            annotationMode: _app_options.AppOptions.get("annotationMode"),
            annotationEditorMode,
            imageResourcesPath: _app_options.AppOptions.get("imageResourcesPath"),
            enablePrintAutoRotate: _app_options.AppOptions.get("enablePrintAutoRotate"),
            useOnlyCssZoom: _app_options.AppOptions.get("useOnlyCssZoom"),
            maxCanvasPixels: _app_options.AppOptions.get("maxCanvasPixels"),
            enablePermissions: _app_options.AppOptions.get("enablePermissions"),
            pageColors
          });
          pdfRenderingQueue.setViewer(this.pdfViewer);
          pdfLinkService.setViewer(this.pdfViewer);
          pdfScriptingManager.setViewer(this.pdfViewer);
          this.pdfThumbnailViewer = new _pdf_thumbnail_viewer.PDFThumbnailViewer({
            container: appConfig.sidebar.thumbnailView,
            eventBus,
            renderingQueue: pdfRenderingQueue,
            linkService: pdfLinkService,
            l10n: this.l10n,
            pageColors
          });
          pdfRenderingQueue.setThumbnailViewer(this.pdfThumbnailViewer);
          if (!this.isViewerEmbedded && !_app_options.AppOptions.get("disableHistory")) {
            this.pdfHistory = new _pdf_history.PDFHistory({
              linkService: pdfLinkService,
              eventBus
            });
            pdfLinkService.setHistory(this.pdfHistory);
          }
          if (!this.supportsIntegratedFind) {
            this.findBar = new _pdf_find_bar.PDFFindBar(appConfig.findBar, eventBus, this.l10n);
          }
          if (annotationEditorMode !== _pdfjsLib.AnnotationEditorType.DISABLE) {
            this.annotationEditorParams = new _annotation_editor_params.AnnotationEditorParams(appConfig.annotationEditorParams, eventBus);
            for (const element of [document.getElementById("editorModeButtons"), document.getElementById("editorModeSeparator")]) {
              element.classList.remove("hidden");
            }
          }
          this.pdfDocumentProperties = new _pdf_document_properties.PDFDocumentProperties(appConfig.documentProperties, this.overlayManager, eventBus, this.l10n, () => {
            return this._docFilename;
          });
          this.pdfCursorTools = new _pdf_cursor_tools.PDFCursorTools({
            container,
            eventBus,
            cursorToolOnLoad: _app_options.AppOptions.get("cursorToolOnLoad")
          });
          this.toolbar = new _toolbar.Toolbar(appConfig.toolbar, eventBus, this.l10n);
          this.secondaryToolbar = new _secondary_toolbar.SecondaryToolbar(appConfig.secondaryToolbar, eventBus);
          if (this.supportsFullscreen) {
            this.pdfPresentationMode = new _pdf_presentation_mode.PDFPresentationMode({
              container,
              pdfViewer: this.pdfViewer,
              eventBus
            });
          }
          this.passwordPrompt = new _password_prompt.PasswordPrompt(appConfig.passwordOverlay, this.overlayManager, this.l10n, this.isViewerEmbedded);
          this.pdfOutlineViewer = new _pdf_outline_viewer.PDFOutlineViewer({
            container: appConfig.sidebar.outlineView,
            eventBus,
            linkService: pdfLinkService
          });
          this.pdfAttachmentViewer = new _pdf_attachment_viewer.PDFAttachmentViewer({
            container: appConfig.sidebar.attachmentsView,
            eventBus,
            downloadManager
          });
          this.pdfLayerViewer = new _pdf_layer_viewer.PDFLayerViewer({
            container: appConfig.sidebar.layersView,
            eventBus,
            l10n: this.l10n
          });
          this.pdfSidebar = new _pdf_sidebar.PDFSidebar({
            elements: appConfig.sidebar,
            pdfViewer: this.pdfViewer,
            pdfThumbnailViewer: this.pdfThumbnailViewer,
            eventBus,
            l10n: this.l10n
          });
          this.pdfSidebar.onToggled = this.forceRendering.bind(this);
          this.pdfSidebarResizer = new _pdf_sidebar_resizer.PDFSidebarResizer(appConfig.sidebarResizer, eventBus, this.l10n);
        },
        run(config) {
          this.initialize(config).then(webViewerInitialized);
        },
        get initialized() {
          return this._initializedCapability.settled;
        },
        get initializedPromise() {
          return this._initializedCapability.promise;
        },
        zoomIn(steps) {
          if (this.pdfViewer.isInPresentationMode) {
            return;
          }
          this.pdfViewer.increaseScale(steps);
        },
        zoomOut(steps) {
          if (this.pdfViewer.isInPresentationMode) {
            return;
          }
          this.pdfViewer.decreaseScale(steps);
        },
        zoomReset() {
          if (this.pdfViewer.isInPresentationMode) {
            return;
          }
          this.pdfViewer.currentScaleValue = _ui_utils.DEFAULT_SCALE_VALUE;
        },
        get pagesCount() {
          return this.pdfDocument ? this.pdfDocument.numPages : 0;
        },
        get page() {
          return this.pdfViewer.currentPageNumber;
        },
        set page(val) {
          this.pdfViewer.currentPageNumber = val;
        },
        get supportsPrinting() {
          return PDFPrintServiceFactory.instance.supportsPrinting;
        },
        get supportsFullscreen() {
          return (0, _pdfjsLib.shadow)(this, "supportsFullscreen", document.fullscreenEnabled);
        },
        get supportsIntegratedFind() {
          return this.externalServices.supportsIntegratedFind;
        },
        get supportsDocumentFonts() {
          return this.externalServices.supportsDocumentFonts;
        },
        get loadingBar() {
          const bar = new _ui_utils.ProgressBar("loadingBar");
          return (0, _pdfjsLib.shadow)(this, "loadingBar", bar);
        },
        get supportedMouseWheelZoomModifierKeys() {
          return this.externalServices.supportedMouseWheelZoomModifierKeys;
        },
        initPassiveLoading() {
          throw new Error("Not implemented: initPassiveLoading");
        },
        setTitleUsingUrl(url = "", downloadUrl = null) {
          this.url = url;
          this.baseUrl = url.split("#")[0];
          if (downloadUrl) {
            this._downloadUrl = downloadUrl === url ? this.baseUrl : downloadUrl.split("#")[0];
          }
          let title = (0, _pdfjsLib.getPdfFilenameFromUrl)(url, "");
          if (!title) {
            try {
              title = decodeURIComponent((0, _pdfjsLib.getFilenameFromUrl)(url)) || url;
            } catch (ex) {
              title = url;
            }
          }
          this.setTitle(title);
        },
        setTitle(title = this._title) {
          this._title = title;
          if (this.isViewerEmbedded) {
            return;
          }
          document.title = `${this._hasAnnotationEditors ? "* " : ""}${title}`;
        },
        get _docFilename() {
          return this._contentDispositionFilename || (0, _pdfjsLib.getPdfFilenameFromUrl)(this.url);
        },
        _hideViewBookmark() {
          const {
            toolbar,
            secondaryToolbar
          } = this.appConfig;
          toolbar.viewBookmark.hidden = true;
          secondaryToolbar.viewBookmarkButton.hidden = true;
        },
        _cancelIdleCallbacks() {
          if (!this._idleCallbacks.size) {
            return;
          }
          for (const callback of this._idleCallbacks) {
            window.cancelIdleCallback(callback);
          }
          this._idleCallbacks.clear();
        },
        async close() {
          var _a, _b, _c, _d;
          this._unblockDocumentLoadEvent();
          this._hideViewBookmark();
          const {
            container
          } = this.appConfig.errorWrapper;
          container.hidden = true;
          if (!this.pdfLoadingTask) {
            return;
          }
          if (((_a = this.pdfDocument) == null ? void 0 : _a.annotationStorage.size) > 0 && this._annotationStorageModified) {
            try {
              await this.save();
            } catch (reason) {
            }
          }
          const promises = [];
          promises.push(this.pdfLoadingTask.destroy());
          this.pdfLoadingTask = null;
          if (this.pdfDocument) {
            this.pdfDocument = null;
            this.pdfThumbnailViewer.setDocument(null);
            this.pdfViewer.setDocument(null);
            this.pdfLinkService.setDocument(null);
            this.pdfDocumentProperties.setDocument(null);
          }
          this.pdfLinkService.externalLinkEnabled = true;
          this.store = null;
          this.isInitialViewSet = false;
          this.downloadComplete = false;
          this.url = "";
          this.baseUrl = "";
          this._downloadUrl = "";
          this.documentInfo = null;
          this.metadata = null;
          this._contentDispositionFilename = null;
          this._contentLength = null;
          this._saveInProgress = false;
          this._docStats = null;
          this._hasAnnotationEditors = false;
          this._cancelIdleCallbacks();
          promises.push(this.pdfScriptingManager.destroyPromise);
          this.setTitle();
          this.pdfSidebar.reset();
          this.pdfOutlineViewer.reset();
          this.pdfAttachmentViewer.reset();
          this.pdfLayerViewer.reset();
          (_b = this.pdfHistory) == null ? void 0 : _b.reset();
          (_c = this.findBar) == null ? void 0 : _c.reset();
          this.toolbar.reset();
          this.secondaryToolbar.reset();
          (_d = this._PDFBug) == null ? void 0 : _d.cleanup();
          await Promise.all(promises);
        },
        async open(file, args) {
          if (this.pdfLoadingTask) {
            await this.close();
          }
          const workerParameters = _app_options.AppOptions.getAll(_app_options.OptionKind.WORKER);
          for (const key in workerParameters) {
            _pdfjsLib.GlobalWorkerOptions[key] = workerParameters[key];
          }
          const parameters = /* @__PURE__ */ Object.create(null);
          if (typeof file === "string") {
            this.setTitleUsingUrl(file, file);
            parameters.url = file;
          } else if (file && "byteLength" in file) {
            parameters.data = file;
          } else if (file.url && file.originalUrl) {
            this.setTitleUsingUrl(file.originalUrl, file.url);
            parameters.url = file.url;
          }
          const apiParameters = _app_options.AppOptions.getAll(_app_options.OptionKind.API);
          for (const key in apiParameters) {
            let value = apiParameters[key];
            if (key === "docBaseUrl" && !value) {
            }
            parameters[key] = value;
          }
          if (args) {
            for (const key in args) {
              parameters[key] = args[key];
            }
          }
          const loadingTask = (0, _pdfjsLib.getDocument)(parameters);
          this.pdfLoadingTask = loadingTask;
          loadingTask.onPassword = (updateCallback, reason) => {
            this.pdfLinkService.externalLinkEnabled = false;
            this.passwordPrompt.setUpdateCallback(updateCallback, reason);
            this.passwordPrompt.open();
          };
          loadingTask.onProgress = ({
            loaded,
            total
          }) => {
            this.progress(loaded / total);
          };
          loadingTask.onUnsupportedFeature = this.fallback.bind(this);
          return loadingTask.promise.then((pdfDocument) => {
            this.load(pdfDocument);
          }, (reason) => {
            if (loadingTask !== this.pdfLoadingTask) {
              return void 0;
            }
            let key = "loading_error";
            if (reason instanceof _pdfjsLib.InvalidPDFException) {
              key = "invalid_file_error";
            } else if (reason instanceof _pdfjsLib.MissingPDFException) {
              key = "missing_file_error";
            } else if (reason instanceof _pdfjsLib.UnexpectedResponseException) {
              key = "unexpected_response_error";
            }
            return this.l10n.get(key).then((msg) => {
              this._documentError(msg, {
                message: reason == null ? void 0 : reason.message
              });
              throw reason;
            });
          });
        },
        _ensureDownloadComplete() {
          if (this.pdfDocument && this.downloadComplete) {
            return;
          }
          throw new Error("PDF document not downloaded.");
        },
        async download() {
          const url = this._downloadUrl, filename = this._docFilename;
          try {
            this._ensureDownloadComplete();
            const data = await this.pdfDocument.getData();
            const blob = new Blob([data], {
              type: "application/pdf"
            });
            await this.downloadManager.download(blob, url, filename);
          } catch (reason) {
            await this.downloadManager.downloadUrl(url, filename);
          }
        },
        async save() {
          if (this._saveInProgress) {
            return;
          }
          this._saveInProgress = true;
          await this.pdfScriptingManager.dispatchWillSave();
          const url = this._downloadUrl, filename = this._docFilename;
          try {
            this._ensureDownloadComplete();
            const data = await this.pdfDocument.saveDocument();
            const blob = new Blob([data], {
              type: "application/pdf"
            });
            await this.downloadManager.download(blob, url, filename);
          } catch (reason) {
            console.error(`Error when saving the document: ${reason.message}`);
            await this.download();
          } finally {
            await this.pdfScriptingManager.dispatchDidSave();
            this._saveInProgress = false;
          }
          if (this._hasAnnotationEditors) {
            this.externalServices.reportTelemetry({
              type: "editing",
              data: {
                type: "save"
              }
            });
          }
        },
        downloadOrSave() {
          var _a;
          if (((_a = this.pdfDocument) == null ? void 0 : _a.annotationStorage.size) > 0) {
            this.save();
          } else {
            this.download();
          }
        },
        fallback(featureId) {
          this.externalServices.reportTelemetry({
            type: "unsupportedFeature",
            featureId
          });
        },
        _documentError(message, moreInfo = null) {
          this._unblockDocumentLoadEvent();
          this._otherError(message, moreInfo);
          this.eventBus.dispatch("documenterror", {
            source: this,
            message,
            reason: (moreInfo == null ? void 0 : moreInfo.message) ?? null
          });
        },
        _otherError(message, moreInfo = null) {
          const moreInfoText = [this.l10n.get("error_version_info", {
            version: _pdfjsLib.version || "?",
            build: _pdfjsLib.build || "?"
          })];
          if (moreInfo) {
            moreInfoText.push(this.l10n.get("error_message", {
              message: moreInfo.message
            }));
            if (moreInfo.stack) {
              moreInfoText.push(this.l10n.get("error_stack", {
                stack: moreInfo.stack
              }));
            } else {
              if (moreInfo.filename) {
                moreInfoText.push(this.l10n.get("error_file", {
                  file: moreInfo.filename
                }));
              }
              if (moreInfo.lineNumber) {
                moreInfoText.push(this.l10n.get("error_line", {
                  line: moreInfo.lineNumber
                }));
              }
            }
          }
          const errorWrapperConfig = this.appConfig.errorWrapper;
          const errorWrapper = errorWrapperConfig.container;
          errorWrapper.hidden = false;
          const errorMessage = errorWrapperConfig.errorMessage;
          errorMessage.textContent = message;
          const closeButton = errorWrapperConfig.closeButton;
          closeButton.onclick = function() {
            errorWrapper.hidden = true;
          };
          const errorMoreInfo = errorWrapperConfig.errorMoreInfo;
          const moreInfoButton = errorWrapperConfig.moreInfoButton;
          const lessInfoButton = errorWrapperConfig.lessInfoButton;
          moreInfoButton.onclick = function() {
            errorMoreInfo.hidden = false;
            moreInfoButton.hidden = true;
            lessInfoButton.hidden = false;
            errorMoreInfo.style.height = errorMoreInfo.scrollHeight + "px";
          };
          lessInfoButton.onclick = function() {
            errorMoreInfo.hidden = true;
            moreInfoButton.hidden = false;
            lessInfoButton.hidden = true;
          };
          moreInfoButton.oncontextmenu = _ui_utils.noContextMenuHandler;
          lessInfoButton.oncontextmenu = _ui_utils.noContextMenuHandler;
          closeButton.oncontextmenu = _ui_utils.noContextMenuHandler;
          moreInfoButton.hidden = false;
          lessInfoButton.hidden = true;
          Promise.all(moreInfoText).then((parts) => {
            errorMoreInfo.value = parts.join("\n");
          });
        },
        progress(level) {
          var _a;
          if (this.downloadComplete) {
            return;
          }
          const percent = Math.round(level * 100);
          if (percent <= this.loadingBar.percent) {
            return;
          }
          this.loadingBar.percent = percent;
          const disableAutoFetch = ((_a = this.pdfDocument) == null ? void 0 : _a.loadingParams.disableAutoFetch) ?? _app_options.AppOptions.get("disableAutoFetch");
          if (!disableAutoFetch || isNaN(percent)) {
            return;
          }
          if (this.disableAutoFetchLoadingBarTimeout) {
            clearTimeout(this.disableAutoFetchLoadingBarTimeout);
            this.disableAutoFetchLoadingBarTimeout = null;
          }
          this.loadingBar.show();
          this.disableAutoFetchLoadingBarTimeout = setTimeout(() => {
            this.loadingBar.hide();
            this.disableAutoFetchLoadingBarTimeout = null;
          }, DISABLE_AUTO_FETCH_LOADING_BAR_TIMEOUT);
        },
        load(pdfDocument) {
          this.pdfDocument = pdfDocument;
          pdfDocument.getDownloadInfo().then(({
            length
          }) => {
            this._contentLength = length;
            this.downloadComplete = true;
            this.loadingBar.hide();
            firstPagePromise.then(() => {
              this.eventBus.dispatch("documentloaded", {
                source: this
              });
            });
          });
          const pageLayoutPromise = pdfDocument.getPageLayout().catch(function() {
          });
          const pageModePromise = pdfDocument.getPageMode().catch(function() {
          });
          const openActionPromise = pdfDocument.getOpenAction().catch(function() {
          });
          this.toolbar.setPagesCount(pdfDocument.numPages, false);
          this.secondaryToolbar.setPagesCount(pdfDocument.numPages);
          let baseDocumentUrl;
          baseDocumentUrl = null;
          this.pdfLinkService.setDocument(pdfDocument, baseDocumentUrl);
          this.pdfDocumentProperties.setDocument(pdfDocument);
          const pdfViewer = this.pdfViewer;
          pdfViewer.setDocument(pdfDocument);
          const {
            firstPagePromise,
            onePageRendered,
            pagesPromise
          } = pdfViewer;
          const pdfThumbnailViewer = this.pdfThumbnailViewer;
          pdfThumbnailViewer.setDocument(pdfDocument);
          const storedPromise = (this.store = new _view_history.ViewHistory(pdfDocument.fingerprints[0])).getMultiple({
            page: null,
            zoom: _ui_utils.DEFAULT_SCALE_VALUE,
            scrollLeft: "0",
            scrollTop: "0",
            rotation: null,
            sidebarView: _ui_utils.SidebarView.UNKNOWN,
            scrollMode: _ui_utils.ScrollMode.UNKNOWN,
            spreadMode: _ui_utils.SpreadMode.UNKNOWN
          }).catch(() => {
            return /* @__PURE__ */ Object.create(null);
          });
          firstPagePromise.then((pdfPage) => {
            this.loadingBar.setWidth(this.appConfig.viewerContainer);
            this._initializeAnnotationStorageCallbacks(pdfDocument);
            Promise.all([_ui_utils.animationStarted, storedPromise, pageLayoutPromise, pageModePromise, openActionPromise]).then(async ([timeStamp, stored, pageLayout, pageMode, openAction]) => {
              const viewOnLoad = _app_options.AppOptions.get("viewOnLoad");
              this._initializePdfHistory({
                fingerprint: pdfDocument.fingerprints[0],
                viewOnLoad,
                initialDest: openAction == null ? void 0 : openAction.dest
              });
              const initialBookmark = this.initialBookmark;
              const zoom = _app_options.AppOptions.get("defaultZoomValue");
              let hash = zoom ? `zoom=${zoom}` : null;
              let rotation = null;
              let sidebarView = _app_options.AppOptions.get("sidebarViewOnLoad");
              let scrollMode = _app_options.AppOptions.get("scrollModeOnLoad");
              let spreadMode = _app_options.AppOptions.get("spreadModeOnLoad");
              if (stored.page && viewOnLoad !== ViewOnLoad.INITIAL) {
                hash = `page=${stored.page}&zoom=${zoom || stored.zoom},${stored.scrollLeft},${stored.scrollTop}`;
                rotation = parseInt(stored.rotation, 10);
                if (sidebarView === _ui_utils.SidebarView.UNKNOWN) {
                  sidebarView = stored.sidebarView | 0;
                }
                if (scrollMode === _ui_utils.ScrollMode.UNKNOWN) {
                  scrollMode = stored.scrollMode | 0;
                }
                if (spreadMode === _ui_utils.SpreadMode.UNKNOWN) {
                  spreadMode = stored.spreadMode | 0;
                }
              }
              if (pageMode && sidebarView === _ui_utils.SidebarView.UNKNOWN) {
                sidebarView = (0, _ui_utils.apiPageModeToSidebarView)(pageMode);
              }
              if (pageLayout && scrollMode === _ui_utils.ScrollMode.UNKNOWN && spreadMode === _ui_utils.SpreadMode.UNKNOWN) {
                const modes = (0, _ui_utils.apiPageLayoutToViewerModes)(pageLayout);
                spreadMode = modes.spreadMode;
              }
              this.setInitialView(hash, {
                rotation,
                sidebarView,
                scrollMode,
                spreadMode
              });
              this.eventBus.dispatch("documentinit", {
                source: this
              });
              if (!this.isViewerEmbedded) {
                pdfViewer.focus();
              }
              await Promise.race([pagesPromise, new Promise((resolve) => {
                setTimeout(resolve, FORCE_PAGES_LOADED_TIMEOUT);
              })]);
              if (!initialBookmark && !hash) {
                return;
              }
              if (pdfViewer.hasEqualPageSizes) {
                return;
              }
              this.initialBookmark = initialBookmark;
              pdfViewer.currentScaleValue = pdfViewer.currentScaleValue;
              this.setInitialView(hash);
            }).catch(() => {
              this.setInitialView();
            }).then(function() {
              pdfViewer.update();
            });
          });
          pagesPromise.then(() => {
            this._unblockDocumentLoadEvent();
            this._initializeAutoPrint(pdfDocument, openActionPromise);
          }, (reason) => {
            this.l10n.get("loading_error").then((msg) => {
              this._documentError(msg, {
                message: reason == null ? void 0 : reason.message
              });
            });
          });
          onePageRendered.then((data) => {
            this.externalServices.reportTelemetry({
              type: "pageInfo",
              timestamp: data.timestamp
            });
            pdfDocument.getOutline().then((outline) => {
              if (pdfDocument !== this.pdfDocument) {
                return;
              }
              this.pdfOutlineViewer.render({
                outline,
                pdfDocument
              });
            });
            pdfDocument.getAttachments().then((attachments) => {
              if (pdfDocument !== this.pdfDocument) {
                return;
              }
              this.pdfAttachmentViewer.render({
                attachments
              });
            });
            pdfViewer.optionalContentConfigPromise.then((optionalContentConfig) => {
              if (pdfDocument !== this.pdfDocument) {
                return;
              }
              this.pdfLayerViewer.render({
                optionalContentConfig,
                pdfDocument
              });
            });
            if ("requestIdleCallback" in window) {
              const callback = window.requestIdleCallback(() => {
                this._collectTelemetry(pdfDocument);
                this._idleCallbacks.delete(callback);
              }, {
                timeout: 1e3
              });
              this._idleCallbacks.add(callback);
            }
          });
          this._initializePageLabels(pdfDocument);
          this._initializeMetadata(pdfDocument);
        },
        async _scriptingDocProperties(pdfDocument) {
          var _a, _b;
          if (!this.documentInfo) {
            await new Promise((resolve) => {
              this.eventBus._on("metadataloaded", resolve, {
                once: true
              });
            });
            if (pdfDocument !== this.pdfDocument) {
              return null;
            }
          }
          if (!this._contentLength) {
            await new Promise((resolve) => {
              this.eventBus._on("documentloaded", resolve, {
                once: true
              });
            });
            if (pdfDocument !== this.pdfDocument) {
              return null;
            }
          }
          return {
            ...this.documentInfo,
            baseURL: this.baseUrl,
            filesize: this._contentLength,
            filename: this._docFilename,
            metadata: (_a = this.metadata) == null ? void 0 : _a.getRaw(),
            authors: (_b = this.metadata) == null ? void 0 : _b.get("dc:creator"),
            numPages: this.pagesCount,
            URL: this.url
          };
        },
        async _collectTelemetry(pdfDocument) {
          const markInfo = await this.pdfDocument.getMarkInfo();
          if (pdfDocument !== this.pdfDocument) {
            return;
          }
          const tagged = (markInfo == null ? void 0 : markInfo.Marked) || false;
          this.externalServices.reportTelemetry({
            type: "tagged",
            tagged
          });
        },
        async _initializeAutoPrint(pdfDocument, openActionPromise) {
          const [openAction, javaScript] = await Promise.all([openActionPromise, !this.pdfViewer.enableScripting ? pdfDocument.getJavaScript() : null]);
          if (pdfDocument !== this.pdfDocument) {
            return;
          }
          let triggerAutoPrint = false;
          if ((openAction == null ? void 0 : openAction.action) === "Print") {
            triggerAutoPrint = true;
          }
          if (javaScript) {
            javaScript.some((js) => {
              if (!js) {
                return false;
              }
              console.warn("Warning: JavaScript support is not enabled");
              this.fallback(_pdfjsLib.UNSUPPORTED_FEATURES.javaScript);
              return true;
            });
            if (!triggerAutoPrint) {
              for (const js of javaScript) {
                if (js && _ui_utils.AutoPrintRegExp.test(js)) {
                  triggerAutoPrint = true;
                  break;
                }
              }
            }
          }
          if (triggerAutoPrint) {
            this.triggerPrinting();
          }
        },
        async _initializeMetadata(pdfDocument) {
          const {
            info,
            metadata,
            contentDispositionFilename,
            contentLength
          } = await pdfDocument.getMetadata();
          if (pdfDocument !== this.pdfDocument) {
            return;
          }
          this.documentInfo = info;
          this.metadata = metadata;
          this._contentDispositionFilename ?? (this._contentDispositionFilename = contentDispositionFilename);
          this._contentLength ?? (this._contentLength = contentLength);
          console.log(`PDF ${pdfDocument.fingerprints[0]} [${info.PDFFormatVersion} ${(info.Producer || "-").trim()} / ${(info.Creator || "-").trim()}] (PDF.js: ${_pdfjsLib.version || "-"})`);
          let pdfTitle = info.Title;
          const metadataTitle = metadata == null ? void 0 : metadata.get("dc:title");
          if (metadataTitle) {
            if (metadataTitle !== "Untitled" && !/[\uFFF0-\uFFFF]/g.test(metadataTitle)) {
              pdfTitle = metadataTitle;
            }
          }
          if (pdfTitle) {
            this.setTitle(`${pdfTitle} - ${this._contentDispositionFilename || this._title}`);
          } else if (this._contentDispositionFilename) {
            this.setTitle(this._contentDispositionFilename);
          }
          if (info.IsXFAPresent && !info.IsAcroFormPresent && !pdfDocument.isPureXfa) {
            if (pdfDocument.loadingParams.enableXfa) {
              console.warn("Warning: XFA Foreground documents are not supported");
            } else {
              console.warn("Warning: XFA support is not enabled");
            }
            this.fallback(_pdfjsLib.UNSUPPORTED_FEATURES.forms);
          } else if ((info.IsAcroFormPresent || info.IsXFAPresent) && !this.pdfViewer.renderForms) {
            console.warn("Warning: Interactive form support is not enabled");
            this.fallback(_pdfjsLib.UNSUPPORTED_FEATURES.forms);
          }
          if (info.IsSignaturesPresent) {
            console.warn("Warning: Digital signatures validation is not supported");
            this.fallback(_pdfjsLib.UNSUPPORTED_FEATURES.signatures);
          }
          let versionId = "other";
          if (KNOWN_VERSIONS.includes(info.PDFFormatVersion)) {
            versionId = `v${info.PDFFormatVersion.replace(".", "_")}`;
          }
          let generatorId = "other";
          if (info.Producer) {
            const producer = info.Producer.toLowerCase();
            KNOWN_GENERATORS.some(function(generator) {
              if (!producer.includes(generator)) {
                return false;
              }
              generatorId = generator.replace(/[ .-]/g, "_");
              return true;
            });
          }
          let formType = null;
          if (info.IsXFAPresent) {
            formType = "xfa";
          } else if (info.IsAcroFormPresent) {
            formType = "acroform";
          }
          this.externalServices.reportTelemetry({
            type: "documentInfo",
            version: versionId,
            generator: generatorId,
            formType
          });
          this.eventBus.dispatch("metadataloaded", {
            source: this
          });
        },
        async _initializePageLabels(pdfDocument) {
          const labels = await pdfDocument.getPageLabels();
          if (pdfDocument !== this.pdfDocument) {
            return;
          }
          if (!labels || _app_options.AppOptions.get("disablePageLabels")) {
            return;
          }
          const numLabels = labels.length;
          let standardLabels = 0, emptyLabels = 0;
          for (let i = 0; i < numLabels; i++) {
            const label = labels[i];
            if (label === (i + 1).toString()) {
              standardLabels++;
            } else if (label === "") {
              emptyLabels++;
            } else {
              break;
            }
          }
          if (standardLabels >= numLabels || emptyLabels >= numLabels) {
            return;
          }
          const {
            pdfViewer,
            pdfThumbnailViewer,
            toolbar
          } = this;
          pdfViewer.setPageLabels(labels);
          pdfThumbnailViewer.setPageLabels(labels);
          toolbar.setPagesCount(numLabels, true);
          toolbar.setPageNumber(pdfViewer.currentPageNumber, pdfViewer.currentPageLabel);
        },
        _initializePdfHistory({
          fingerprint,
          viewOnLoad,
          initialDest = null
        }) {
          if (!this.pdfHistory) {
            return;
          }
          this.pdfHistory.initialize({
            fingerprint,
            resetHistory: viewOnLoad === ViewOnLoad.INITIAL,
            updateUrl: _app_options.AppOptions.get("historyUpdateUrl")
          });
          if (this.pdfHistory.initialBookmark) {
            this.initialBookmark = this.pdfHistory.initialBookmark;
            this.initialRotation = this.pdfHistory.initialRotation;
          }
          if (initialDest && !this.initialBookmark && viewOnLoad === ViewOnLoad.UNKNOWN) {
            this.initialBookmark = JSON.stringify(initialDest);
            this.pdfHistory.push({
              explicitDest: initialDest,
              pageNumber: null
            });
          }
        },
        _initializeAnnotationStorageCallbacks(pdfDocument) {
          if (pdfDocument !== this.pdfDocument) {
            return;
          }
          const {
            annotationStorage
          } = pdfDocument;
          annotationStorage.onSetModified = () => {
            window.addEventListener("beforeunload", beforeUnload);
            this._annotationStorageModified = true;
          };
          annotationStorage.onResetModified = () => {
            window.removeEventListener("beforeunload", beforeUnload);
            delete this._annotationStorageModified;
          };
          annotationStorage.onAnnotationEditor = (typeStr) => {
            this._hasAnnotationEditors = !!typeStr;
            this.setTitle();
            if (typeStr) {
              this.externalServices.reportTelemetry({
                type: "editing",
                data: {
                  type: typeStr
                }
              });
            }
          };
        },
        setInitialView(storedHash, {
          rotation,
          sidebarView,
          scrollMode,
          spreadMode
        } = {}) {
          const setRotation = (angle) => {
            if ((0, _ui_utils.isValidRotation)(angle)) {
              this.pdfViewer.pagesRotation = angle;
            }
          };
          const setViewerModes = (scroll, spread) => {
            if ((0, _ui_utils.isValidScrollMode)(scroll)) {
              this.pdfViewer.scrollMode = scroll;
            }
            if ((0, _ui_utils.isValidSpreadMode)(spread)) {
              this.pdfViewer.spreadMode = spread;
            }
          };
          this.isInitialViewSet = true;
          this.pdfSidebar.setInitialView(sidebarView);
          setViewerModes(scrollMode, spreadMode);
          if (this.initialBookmark) {
            setRotation(this.initialRotation);
            delete this.initialRotation;
            this.pdfLinkService.setHash(this.initialBookmark);
            this.initialBookmark = null;
          } else if (storedHash) {
            setRotation(rotation);
            this.pdfLinkService.setHash(storedHash);
          }
          this.toolbar.setPageNumber(this.pdfViewer.currentPageNumber, this.pdfViewer.currentPageLabel);
          this.secondaryToolbar.setPageNumber(this.pdfViewer.currentPageNumber);
          if (!this.pdfViewer.currentScaleValue) {
            this.pdfViewer.currentScaleValue = _ui_utils.DEFAULT_SCALE_VALUE;
          }
        },
        _cleanup() {
          if (!this.pdfDocument) {
            return;
          }
          this.pdfViewer.cleanup();
          this.pdfThumbnailViewer.cleanup();
          this.pdfDocument.cleanup(this.pdfViewer.renderer === _ui_utils.RendererType.SVG);
        },
        forceRendering() {
          this.pdfRenderingQueue.printing = !!this.printService;
          this.pdfRenderingQueue.isThumbnailViewEnabled = this.pdfSidebar.visibleView === _ui_utils.SidebarView.THUMBS;
          this.pdfRenderingQueue.renderHighestPriority();
        },
        beforePrint() {
          this._printAnnotationStoragePromise = this.pdfScriptingManager.dispatchWillPrint().catch(() => {
          }).then(() => {
            var _a;
            return (_a = this.pdfDocument) == null ? void 0 : _a.annotationStorage.print;
          });
          if (this.printService) {
            return;
          }
          if (!this.supportsPrinting) {
            this.l10n.get("printing_not_supported").then((msg) => {
              this._otherError(msg);
            });
            return;
          }
          if (!this.pdfViewer.pageViewsReady) {
            this.l10n.get("printing_not_ready").then((msg) => {
              window.alert(msg);
            });
            return;
          }
          const pagesOverview = this.pdfViewer.getPagesOverview();
          const printContainer = this.appConfig.printContainer;
          const printResolution = _app_options.AppOptions.get("printResolution");
          const optionalContentConfigPromise = this.pdfViewer.optionalContentConfigPromise;
          const printService = PDFPrintServiceFactory.instance.createPrintService(this.pdfDocument, pagesOverview, printContainer, printResolution, optionalContentConfigPromise, this._printAnnotationStoragePromise, this.l10n);
          this.printService = printService;
          this.forceRendering();
          printService.layout();
          this.externalServices.reportTelemetry({
            type: "print"
          });
          if (this._hasAnnotationEditors) {
            this.externalServices.reportTelemetry({
              type: "editing",
              data: {
                type: "print"
              }
            });
          }
        },
        afterPrint() {
          var _a;
          if (this._printAnnotationStoragePromise) {
            this._printAnnotationStoragePromise.then(() => {
              this.pdfScriptingManager.dispatchDidPrint();
            });
            this._printAnnotationStoragePromise = null;
          }
          if (this.printService) {
            this.printService.destroy();
            this.printService = null;
            (_a = this.pdfDocument) == null ? void 0 : _a.annotationStorage.resetModified();
          }
          this.forceRendering();
        },
        rotatePages(delta) {
          this.pdfViewer.pagesRotation += delta;
        },
        requestPresentationMode() {
          var _a;
          (_a = this.pdfPresentationMode) == null ? void 0 : _a.request();
        },
        triggerPrinting() {
          if (!this.supportsPrinting) {
            return;
          }
          window.print();
        },
        bindEvents() {
          const {
            eventBus,
            _boundEvents
          } = this;
          _boundEvents.beforePrint = this.beforePrint.bind(this);
          _boundEvents.afterPrint = this.afterPrint.bind(this);
          eventBus._on("resize", webViewerResize);
          eventBus._on("hashchange", webViewerHashchange);
          eventBus._on("beforeprint", _boundEvents.beforePrint);
          eventBus._on("afterprint", _boundEvents.afterPrint);
          eventBus._on("pagerendered", webViewerPageRendered);
          eventBus._on("updateviewarea", webViewerUpdateViewarea);
          eventBus._on("pagechanging", webViewerPageChanging);
          eventBus._on("scalechanging", webViewerScaleChanging);
          eventBus._on("rotationchanging", webViewerRotationChanging);
          eventBus._on("sidebarviewchanged", webViewerSidebarViewChanged);
          eventBus._on("pagemode", webViewerPageMode);
          eventBus._on("namedaction", webViewerNamedAction);
          eventBus._on("presentationmodechanged", webViewerPresentationModeChanged);
          eventBus._on("presentationmode", webViewerPresentationMode);
          eventBus._on("switchannotationeditormode", webViewerSwitchAnnotationEditorMode);
          eventBus._on("switchannotationeditorparams", webViewerSwitchAnnotationEditorParams);
          eventBus._on("print", webViewerPrint);
          eventBus._on("download", webViewerDownload);
          eventBus._on("firstpage", webViewerFirstPage);
          eventBus._on("lastpage", webViewerLastPage);
          eventBus._on("nextpage", webViewerNextPage);
          eventBus._on("previouspage", webViewerPreviousPage);
          eventBus._on("zoomin", webViewerZoomIn);
          eventBus._on("zoomout", webViewerZoomOut);
          eventBus._on("zoomreset", webViewerZoomReset);
          eventBus._on("pagenumberchanged", webViewerPageNumberChanged);
          eventBus._on("scalechanged", webViewerScaleChanged);
          eventBus._on("rotatecw", webViewerRotateCw);
          eventBus._on("rotateccw", webViewerRotateCcw);
          eventBus._on("optionalcontentconfig", webViewerOptionalContentConfig);
          eventBus._on("switchscrollmode", webViewerSwitchScrollMode);
          eventBus._on("scrollmodechanged", webViewerScrollModeChanged);
          eventBus._on("switchspreadmode", webViewerSwitchSpreadMode);
          eventBus._on("spreadmodechanged", webViewerSpreadModeChanged);
          eventBus._on("documentproperties", webViewerDocumentProperties);
          eventBus._on("findfromurlhash", webViewerFindFromUrlHash);
          eventBus._on("updatefindmatchescount", webViewerUpdateFindMatchesCount);
          eventBus._on("updatefindcontrolstate", webViewerUpdateFindControlState);
          if (_app_options.AppOptions.get("pdfBug")) {
            _boundEvents.reportPageStatsPDFBug = reportPageStatsPDFBug;
            eventBus._on("pagerendered", _boundEvents.reportPageStatsPDFBug);
            eventBus._on("pagechanging", _boundEvents.reportPageStatsPDFBug);
          }
          eventBus._on("fileinputchange", webViewerFileInputChange);
          eventBus._on("openfile", webViewerOpenFile);
        },
        bindWindowEvents() {
          const {
            eventBus,
            _boundEvents
          } = this;
          function addWindowResolutionChange(evt = null) {
            if (evt) {
              webViewerResolutionChange(evt);
            }
            const mediaQueryList = window.matchMedia(`(resolution: ${window.devicePixelRatio || 1}dppx)`);
            mediaQueryList.addEventListener("change", addWindowResolutionChange, {
              once: true
            });
            _boundEvents.removeWindowResolutionChange || (_boundEvents.removeWindowResolutionChange = function() {
              mediaQueryList.removeEventListener("change", addWindowResolutionChange);
              _boundEvents.removeWindowResolutionChange = null;
            });
          }
          addWindowResolutionChange();
          _boundEvents.windowResize = () => {
            eventBus.dispatch("resize", {
              source: window
            });
          };
          _boundEvents.windowHashChange = () => {
            eventBus.dispatch("hashchange", {
              source: window,
              hash: document.location.hash.substring(1)
            });
          };
          _boundEvents.windowBeforePrint = () => {
            eventBus.dispatch("beforeprint", {
              source: window
            });
          };
          _boundEvents.windowAfterPrint = () => {
            eventBus.dispatch("afterprint", {
              source: window
            });
          };
          _boundEvents.windowUpdateFromSandbox = (event) => {
            eventBus.dispatch("updatefromsandbox", {
              source: window,
              detail: event.detail
            });
          };
          window.addEventListener("visibilitychange", webViewerVisibilityChange);
          window.addEventListener("wheel", webViewerWheel, {
            passive: false
          });
          window.addEventListener("touchstart", webViewerTouchStart, {
            passive: false
          });
          window.addEventListener("click", webViewerClick);
          window.addEventListener("keydown", webViewerKeyDown);
          window.addEventListener("resize", _boundEvents.windowResize);
          window.addEventListener("hashchange", _boundEvents.windowHashChange);
          window.addEventListener("beforeprint", _boundEvents.windowBeforePrint);
          window.addEventListener("afterprint", _boundEvents.windowAfterPrint);
          window.addEventListener("updatefromsandbox", _boundEvents.windowUpdateFromSandbox);
        },
        unbindEvents() {
          const {
            eventBus,
            _boundEvents
          } = this;
          eventBus._off("resize", webViewerResize);
          eventBus._off("hashchange", webViewerHashchange);
          eventBus._off("beforeprint", _boundEvents.beforePrint);
          eventBus._off("afterprint", _boundEvents.afterPrint);
          eventBus._off("pagerendered", webViewerPageRendered);
          eventBus._off("updateviewarea", webViewerUpdateViewarea);
          eventBus._off("pagechanging", webViewerPageChanging);
          eventBus._off("scalechanging", webViewerScaleChanging);
          eventBus._off("rotationchanging", webViewerRotationChanging);
          eventBus._off("sidebarviewchanged", webViewerSidebarViewChanged);
          eventBus._off("pagemode", webViewerPageMode);
          eventBus._off("namedaction", webViewerNamedAction);
          eventBus._off("presentationmodechanged", webViewerPresentationModeChanged);
          eventBus._off("presentationmode", webViewerPresentationMode);
          eventBus._off("print", webViewerPrint);
          eventBus._off("download", webViewerDownload);
          eventBus._off("firstpage", webViewerFirstPage);
          eventBus._off("lastpage", webViewerLastPage);
          eventBus._off("nextpage", webViewerNextPage);
          eventBus._off("previouspage", webViewerPreviousPage);
          eventBus._off("zoomin", webViewerZoomIn);
          eventBus._off("zoomout", webViewerZoomOut);
          eventBus._off("zoomreset", webViewerZoomReset);
          eventBus._off("pagenumberchanged", webViewerPageNumberChanged);
          eventBus._off("scalechanged", webViewerScaleChanged);
          eventBus._off("rotatecw", webViewerRotateCw);
          eventBus._off("rotateccw", webViewerRotateCcw);
          eventBus._off("optionalcontentconfig", webViewerOptionalContentConfig);
          eventBus._off("switchscrollmode", webViewerSwitchScrollMode);
          eventBus._off("scrollmodechanged", webViewerScrollModeChanged);
          eventBus._off("switchspreadmode", webViewerSwitchSpreadMode);
          eventBus._off("spreadmodechanged", webViewerSpreadModeChanged);
          eventBus._off("documentproperties", webViewerDocumentProperties);
          eventBus._off("findfromurlhash", webViewerFindFromUrlHash);
          eventBus._off("updatefindmatchescount", webViewerUpdateFindMatchesCount);
          eventBus._off("updatefindcontrolstate", webViewerUpdateFindControlState);
          if (_boundEvents.reportPageStatsPDFBug) {
            eventBus._off("pagerendered", _boundEvents.reportPageStatsPDFBug);
            eventBus._off("pagechanging", _boundEvents.reportPageStatsPDFBug);
            _boundEvents.reportPageStatsPDFBug = null;
          }
          eventBus._off("fileinputchange", webViewerFileInputChange);
          eventBus._off("openfile", webViewerOpenFile);
          _boundEvents.beforePrint = null;
          _boundEvents.afterPrint = null;
        },
        unbindWindowEvents() {
          var _a;
          const {
            _boundEvents
          } = this;
          window.removeEventListener("visibilitychange", webViewerVisibilityChange);
          window.removeEventListener("wheel", webViewerWheel, {
            passive: false
          });
          window.removeEventListener("touchstart", webViewerTouchStart, {
            passive: false
          });
          window.removeEventListener("click", webViewerClick);
          window.removeEventListener("keydown", webViewerKeyDown);
          window.removeEventListener("resize", _boundEvents.windowResize);
          window.removeEventListener("hashchange", _boundEvents.windowHashChange);
          window.removeEventListener("beforeprint", _boundEvents.windowBeforePrint);
          window.removeEventListener("afterprint", _boundEvents.windowAfterPrint);
          window.removeEventListener("updatefromsandbox", _boundEvents.windowUpdateFromSandbox);
          (_a = _boundEvents.removeWindowResolutionChange) == null ? void 0 : _a.call(_boundEvents);
          _boundEvents.windowResize = null;
          _boundEvents.windowHashChange = null;
          _boundEvents.windowBeforePrint = null;
          _boundEvents.windowAfterPrint = null;
          _boundEvents.windowUpdateFromSandbox = null;
        },
        accumulateWheelTicks(ticks) {
          if (this._wheelUnusedTicks > 0 && ticks < 0 || this._wheelUnusedTicks < 0 && ticks > 0) {
            this._wheelUnusedTicks = 0;
          }
          this._wheelUnusedTicks += ticks;
          const wholeTicks = Math.sign(this._wheelUnusedTicks) * Math.floor(Math.abs(this._wheelUnusedTicks));
          this._wheelUnusedTicks -= wholeTicks;
          return wholeTicks;
        },
        _unblockDocumentLoadEvent() {
          var _a;
          (_a = document.blockUnblockOnload) == null ? void 0 : _a.call(document, false);
          this._unblockDocumentLoadEvent = () => {
          };
        },
        _reportDocumentStatsTelemetry() {
          const {
            stats
          } = this.pdfDocument;
          if (stats !== this._docStats) {
            this._docStats = stats;
            this.externalServices.reportTelemetry({
              type: "documentStats",
              stats
            });
          }
        },
        get scriptingReady() {
          return this.pdfScriptingManager.ready;
        }
      };
      exports.PDFViewerApplication = PDFViewerApplication;
      let validateFileURL;
      {
        const HOSTED_VIEWER_ORIGINS = ["null", "http://mozilla.github.io", "https://mozilla.github.io"];
        validateFileURL = function(file) {
          if (!file) {
            return;
          }
          try {
            const viewerOrigin = new URL(window.location.href).origin || "null";
            if (HOSTED_VIEWER_ORIGINS.includes(viewerOrigin)) {
              return;
            }
            const fileOrigin = new URL(file, window.location.href).origin;
            if (fileOrigin !== viewerOrigin) {
              throw new Error("file origin does not match viewer's");
            }
          } catch (ex) {
            PDFViewerApplication.l10n.get("loading_error").then((msg) => {
              PDFViewerApplication._documentError(msg, {
                message: ex == null ? void 0 : ex.message
              });
            });
            throw ex;
          }
        };
      }
      async function loadFakeWorker() {
        var _a;
        (_a = _pdfjsLib.GlobalWorkerOptions).workerSrc || (_a.workerSrc = _app_options.AppOptions.get("workerSrc"));
        await (0, _pdfjsLib.loadScript)(_pdfjsLib.PDFWorker.workerSrc);
      }
      async function loadPDFBug(self) {
        const {
          debuggerScriptPath
        } = self.appConfig;
        const {
          PDFBug
        } = await import(debuggerScriptPath);
        self._PDFBug = PDFBug;
      }
      function reportPageStatsPDFBug({
        pageNumber
      }) {
        var _a, _b;
        if (!((_a = globalThis.Stats) == null ? void 0 : _a.enabled)) {
          return;
        }
        const pageView = PDFViewerApplication.pdfViewer.getPageView(pageNumber - 1);
        globalThis.Stats.add(pageNumber, (_b = pageView == null ? void 0 : pageView.pdfPage) == null ? void 0 : _b.stats);
      }
      function webViewerInitialized() {
        const {
          appConfig,
          eventBus
        } = PDFViewerApplication;
        let file;
        const queryString = document.location.search.substring(1);
        const params = (0, _ui_utils.parseQueryString)(queryString);
        file = params.get("file") ?? _app_options.AppOptions.get("defaultUrl");
        validateFileURL(file);
        const fileInput = appConfig.openFileInput;
        fileInput.value = null;
        fileInput.addEventListener("change", function(evt) {
          const {
            files
          } = evt.target;
          if (!files || files.length === 0) {
            return;
          }
          eventBus.dispatch("fileinputchange", {
            source: this,
            fileInput: evt.target
          });
        });
        appConfig.mainContainer.addEventListener("dragover", function(evt) {
          evt.preventDefault();
          evt.dataTransfer.dropEffect = evt.dataTransfer.effectAllowed === "copy" ? "copy" : "move";
        });
        appConfig.mainContainer.addEventListener("drop", function(evt) {
          evt.preventDefault();
          const {
            files
          } = evt.dataTransfer;
          if (!files || files.length === 0) {
            return;
          }
          eventBus.dispatch("fileinputchange", {
            source: this,
            fileInput: evt.dataTransfer
          });
        });
        if (!PDFViewerApplication.supportsDocumentFonts) {
          _app_options.AppOptions.set("disableFontFace", true);
          PDFViewerApplication.l10n.get("web_fonts_disabled").then((msg) => {
            console.warn(msg);
          });
        }
        if (!PDFViewerApplication.supportsPrinting) {
          appConfig.toolbar.print.classList.add("hidden");
          appConfig.secondaryToolbar.printButton.classList.add("hidden");
        }
        if (!PDFViewerApplication.supportsFullscreen) {
          appConfig.toolbar.presentationModeButton.classList.add("hidden");
          appConfig.secondaryToolbar.presentationModeButton.classList.add("hidden");
        }
        if (PDFViewerApplication.supportsIntegratedFind) {
          appConfig.toolbar.viewFind.classList.add("hidden");
        }
        appConfig.mainContainer.addEventListener("transitionend", function(evt) {
          if (evt.target === this) {
            eventBus.dispatch("resize", {
              source: this
            });
          }
        }, true);
        try {
          if (file) {
            PDFViewerApplication.open(file);
          } else {
            PDFViewerApplication._hideViewBookmark();
          }
        } catch (reason) {
          PDFViewerApplication.l10n.get("loading_error").then((msg) => {
            PDFViewerApplication._documentError(msg, reason);
          });
        }
      }
      function webViewerPageRendered({
        pageNumber,
        error
      }) {
        if (pageNumber === PDFViewerApplication.page) {
          PDFViewerApplication.toolbar.updateLoadingIndicatorState(false);
        }
        if (PDFViewerApplication.pdfSidebar.visibleView === _ui_utils.SidebarView.THUMBS) {
          const pageView = PDFViewerApplication.pdfViewer.getPageView(pageNumber - 1);
          const thumbnailView = PDFViewerApplication.pdfThumbnailViewer.getThumbnail(pageNumber - 1);
          if (pageView && thumbnailView) {
            thumbnailView.setImage(pageView);
          }
        }
        if (error) {
          PDFViewerApplication.l10n.get("rendering_error").then((msg) => {
            PDFViewerApplication._otherError(msg, error);
          });
        }
        PDFViewerApplication._reportDocumentStatsTelemetry();
      }
      function webViewerPageMode({
        mode
      }) {
        let view;
        switch (mode) {
          case "thumbs":
            view = _ui_utils.SidebarView.THUMBS;
            break;
          case "bookmarks":
          case "outline":
            view = _ui_utils.SidebarView.OUTLINE;
            break;
          case "attachments":
            view = _ui_utils.SidebarView.ATTACHMENTS;
            break;
          case "layers":
            view = _ui_utils.SidebarView.LAYERS;
            break;
          case "none":
            view = _ui_utils.SidebarView.NONE;
            break;
          default:
            console.error('Invalid "pagemode" hash parameter: ' + mode);
            return;
        }
        PDFViewerApplication.pdfSidebar.switchView(view, true);
      }
      function webViewerNamedAction(evt) {
        switch (evt.action) {
          case "GoToPage":
            PDFViewerApplication.appConfig.toolbar.pageNumber.select();
            break;
          case "Find":
            if (!PDFViewerApplication.supportsIntegratedFind) {
              PDFViewerApplication.findBar.toggle();
            }
            break;
          case "Print":
            PDFViewerApplication.triggerPrinting();
            break;
          case "SaveAs":
            PDFViewerApplication.downloadOrSave();
            break;
        }
      }
      function webViewerPresentationModeChanged(evt) {
        PDFViewerApplication.pdfViewer.presentationModeState = evt.state;
      }
      function webViewerSidebarViewChanged({
        view
      }) {
        var _a;
        PDFViewerApplication.pdfRenderingQueue.isThumbnailViewEnabled = view === _ui_utils.SidebarView.THUMBS;
        if (PDFViewerApplication.isInitialViewSet) {
          (_a = PDFViewerApplication.store) == null ? void 0 : _a.set("sidebarView", view).catch(() => {
          });
        }
      }
      function webViewerUpdateViewarea({
        location
      }) {
        var _a;
        if (PDFViewerApplication.isInitialViewSet) {
          (_a = PDFViewerApplication.store) == null ? void 0 : _a.setMultiple({
            page: location.pageNumber,
            zoom: location.scale,
            scrollLeft: location.left,
            scrollTop: location.top,
            rotation: location.rotation
          }).catch(() => {
          });
        }
        const href = PDFViewerApplication.pdfLinkService.getAnchorUrl(location.pdfOpenParams);
        PDFViewerApplication.appConfig.toolbar.viewBookmark.href = href;
        PDFViewerApplication.appConfig.secondaryToolbar.viewBookmarkButton.href = href;
        const currentPage = PDFViewerApplication.pdfViewer.getPageView(PDFViewerApplication.page - 1);
        const loading = (currentPage == null ? void 0 : currentPage.renderingState) !== _ui_utils.RenderingStates.FINISHED;
        PDFViewerApplication.toolbar.updateLoadingIndicatorState(loading);
      }
      function webViewerScrollModeChanged(evt) {
        var _a;
        if (PDFViewerApplication.isInitialViewSet) {
          (_a = PDFViewerApplication.store) == null ? void 0 : _a.set("scrollMode", evt.mode).catch(() => {
          });
        }
      }
      function webViewerSpreadModeChanged(evt) {
        var _a;
        if (PDFViewerApplication.isInitialViewSet) {
          (_a = PDFViewerApplication.store) == null ? void 0 : _a.set("spreadMode", evt.mode).catch(() => {
          });
        }
      }
      function webViewerResize() {
        const {
          pdfDocument,
          pdfViewer,
          pdfRenderingQueue
        } = PDFViewerApplication;
        if (pdfRenderingQueue.printing && window.matchMedia("print").matches) {
          return;
        }
        pdfViewer.updateContainerHeightCss();
        if (!pdfDocument) {
          return;
        }
        const currentScaleValue = pdfViewer.currentScaleValue;
        if (currentScaleValue === "auto" || currentScaleValue === "page-fit" || currentScaleValue === "page-width") {
          pdfViewer.currentScaleValue = currentScaleValue;
        }
        pdfViewer.update();
      }
      function webViewerHashchange(evt) {
        var _a;
        const hash = evt.hash;
        if (!hash) {
          return;
        }
        if (!PDFViewerApplication.isInitialViewSet) {
          PDFViewerApplication.initialBookmark = hash;
        } else if (!((_a = PDFViewerApplication.pdfHistory) == null ? void 0 : _a.popStateInProgress)) {
          PDFViewerApplication.pdfLinkService.setHash(hash);
        }
      }
      {
        var webViewerFileInputChange = function(evt) {
          var _a;
          if ((_a = PDFViewerApplication.pdfViewer) == null ? void 0 : _a.isInPresentationMode) {
            return;
          }
          const file = evt.fileInput.files[0];
          let url = URL.createObjectURL(file);
          if (file.name) {
            url = {
              url,
              originalUrl: file.name
            };
          }
          PDFViewerApplication.open(url);
        };
        var webViewerOpenFile = function(evt) {
          const fileInput = PDFViewerApplication.appConfig.openFileInput;
          fileInput.click();
        };
      }
      function webViewerPresentationMode() {
        PDFViewerApplication.requestPresentationMode();
      }
      function webViewerSwitchAnnotationEditorMode(evt) {
        PDFViewerApplication.pdfViewer.annotationEditorMode = evt.mode;
      }
      function webViewerSwitchAnnotationEditorParams(evt) {
        PDFViewerApplication.pdfViewer.annotationEditorParams = evt;
      }
      function webViewerPrint() {
        PDFViewerApplication.triggerPrinting();
      }
      function webViewerDownload() {
        PDFViewerApplication.downloadOrSave();
      }
      function webViewerFirstPage() {
        if (PDFViewerApplication.pdfDocument) {
          PDFViewerApplication.page = 1;
        }
      }
      function webViewerLastPage() {
        if (PDFViewerApplication.pdfDocument) {
          PDFViewerApplication.page = PDFViewerApplication.pagesCount;
        }
      }
      function webViewerNextPage() {
        PDFViewerApplication.pdfViewer.nextPage();
      }
      function webViewerPreviousPage() {
        PDFViewerApplication.pdfViewer.previousPage();
      }
      function webViewerZoomIn() {
        PDFViewerApplication.zoomIn();
      }
      function webViewerZoomOut() {
        PDFViewerApplication.zoomOut();
      }
      function webViewerZoomReset() {
        PDFViewerApplication.zoomReset();
      }
      function webViewerPageNumberChanged(evt) {
        const pdfViewer = PDFViewerApplication.pdfViewer;
        if (evt.value !== "") {
          PDFViewerApplication.pdfLinkService.goToPage(evt.value);
        }
        if (evt.value !== pdfViewer.currentPageNumber.toString() && evt.value !== pdfViewer.currentPageLabel) {
          PDFViewerApplication.toolbar.setPageNumber(pdfViewer.currentPageNumber, pdfViewer.currentPageLabel);
        }
      }
      function webViewerScaleChanged(evt) {
        PDFViewerApplication.pdfViewer.currentScaleValue = evt.value;
      }
      function webViewerRotateCw() {
        PDFViewerApplication.rotatePages(90);
      }
      function webViewerRotateCcw() {
        PDFViewerApplication.rotatePages(-90);
      }
      function webViewerOptionalContentConfig(evt) {
        PDFViewerApplication.pdfViewer.optionalContentConfigPromise = evt.promise;
      }
      function webViewerSwitchScrollMode(evt) {
        PDFViewerApplication.pdfViewer.scrollMode = evt.mode;
      }
      function webViewerSwitchSpreadMode(evt) {
        PDFViewerApplication.pdfViewer.spreadMode = evt.mode;
      }
      function webViewerDocumentProperties() {
        PDFViewerApplication.pdfDocumentProperties.open();
      }
      function webViewerFindFromUrlHash(evt) {
        PDFViewerApplication.eventBus.dispatch("find", {
          source: evt.source,
          type: "",
          query: evt.query,
          phraseSearch: evt.phraseSearch,
          caseSensitive: false,
          entireWord: false,
          highlightAll: true,
          findPrevious: false,
          matchDiacritics: true
        });
      }
      function webViewerUpdateFindMatchesCount({
        matchesCount
      }) {
        if (PDFViewerApplication.supportsIntegratedFind) {
          PDFViewerApplication.externalServices.updateFindMatchesCount(matchesCount);
        } else {
          PDFViewerApplication.findBar.updateResultsCount(matchesCount);
        }
      }
      function webViewerUpdateFindControlState({
        state,
        previous,
        matchesCount,
        rawQuery
      }) {
        if (PDFViewerApplication.supportsIntegratedFind) {
          PDFViewerApplication.externalServices.updateFindControlState({
            result: state,
            findPrevious: previous,
            matchesCount,
            rawQuery
          });
        } else {
          PDFViewerApplication.findBar.updateUIState(state, previous, matchesCount);
        }
      }
      function webViewerScaleChanging(evt) {
        PDFViewerApplication.toolbar.setPageScale(evt.presetValue, evt.scale);
        PDFViewerApplication.pdfViewer.update();
      }
      function webViewerRotationChanging(evt) {
        PDFViewerApplication.pdfThumbnailViewer.pagesRotation = evt.pagesRotation;
        PDFViewerApplication.forceRendering();
        PDFViewerApplication.pdfViewer.currentPageNumber = evt.pageNumber;
      }
      function webViewerPageChanging({
        pageNumber,
        pageLabel
      }) {
        PDFViewerApplication.toolbar.setPageNumber(pageNumber, pageLabel);
        PDFViewerApplication.secondaryToolbar.setPageNumber(pageNumber);
        if (PDFViewerApplication.pdfSidebar.visibleView === _ui_utils.SidebarView.THUMBS) {
          PDFViewerApplication.pdfThumbnailViewer.scrollThumbnailIntoView(pageNumber);
        }
      }
      function webViewerResolutionChange(evt) {
        PDFViewerApplication.pdfViewer.refresh();
      }
      function webViewerVisibilityChange(evt) {
        if (document.visibilityState === "visible") {
          setZoomDisabledTimeout();
        }
      }
      let zoomDisabledTimeout = null;
      function setZoomDisabledTimeout() {
        if (zoomDisabledTimeout) {
          clearTimeout(zoomDisabledTimeout);
        }
        zoomDisabledTimeout = setTimeout(function() {
          zoomDisabledTimeout = null;
        }, WHEEL_ZOOM_DISABLED_TIMEOUT);
      }
      function webViewerWheel(evt) {
        const {
          pdfViewer,
          supportedMouseWheelZoomModifierKeys
        } = PDFViewerApplication;
        if (pdfViewer.isInPresentationMode) {
          return;
        }
        if (evt.ctrlKey && supportedMouseWheelZoomModifierKeys.ctrlKey || evt.metaKey && supportedMouseWheelZoomModifierKeys.metaKey) {
          evt.preventDefault();
          if (zoomDisabledTimeout || document.visibilityState === "hidden") {
            return;
          }
          const deltaMode = evt.deltaMode;
          const delta = (0, _ui_utils.normalizeWheelEventDirection)(evt);
          const previousScale = pdfViewer.currentScale;
          let ticks = 0;
          if (deltaMode === WheelEvent.DOM_DELTA_LINE || deltaMode === WheelEvent.DOM_DELTA_PAGE) {
            if (Math.abs(delta) >= 1) {
              ticks = Math.sign(delta);
            } else {
              ticks = PDFViewerApplication.accumulateWheelTicks(delta);
            }
          } else {
            const PIXELS_PER_LINE_SCALE = 30;
            ticks = PDFViewerApplication.accumulateWheelTicks(delta / PIXELS_PER_LINE_SCALE);
          }
          if (ticks < 0) {
            PDFViewerApplication.zoomOut(-ticks);
          } else if (ticks > 0) {
            PDFViewerApplication.zoomIn(ticks);
          }
          const currentScale = pdfViewer.currentScale;
          if (previousScale !== currentScale) {
            const scaleCorrectionFactor = currentScale / previousScale - 1;
            const rect = pdfViewer.container.getBoundingClientRect();
            const dx = evt.clientX - rect.left;
            const dy = evt.clientY - rect.top;
            pdfViewer.container.scrollLeft += dx * scaleCorrectionFactor;
            pdfViewer.container.scrollTop += dy * scaleCorrectionFactor;
          }
        } else {
          setZoomDisabledTimeout();
        }
      }
      function webViewerTouchStart(evt) {
        if (evt.touches.length > 1) {
          evt.preventDefault();
        }
      }
      function webViewerClick(evt) {
        if (!PDFViewerApplication.secondaryToolbar.isOpen) {
          return;
        }
        const appConfig = PDFViewerApplication.appConfig;
        if (PDFViewerApplication.pdfViewer.containsElement(evt.target) || appConfig.toolbar.container.contains(evt.target) && evt.target !== appConfig.secondaryToolbar.toggleButton) {
          PDFViewerApplication.secondaryToolbar.close();
        }
      }
      function webViewerKeyDown(evt) {
        if (PDFViewerApplication.overlayManager.active) {
          return;
        }
        const {
          eventBus,
          pdfViewer
        } = PDFViewerApplication;
        const isViewerInPresentationMode = pdfViewer.isInPresentationMode;
        let handled = false, ensureViewerFocused = false;
        const cmd = (evt.ctrlKey ? 1 : 0) | (evt.altKey ? 2 : 0) | (evt.shiftKey ? 4 : 0) | (evt.metaKey ? 8 : 0);
        if (cmd === 1 || cmd === 8 || cmd === 5 || cmd === 12) {
          switch (evt.keyCode) {
            case 70:
              if (!PDFViewerApplication.supportsIntegratedFind && !evt.shiftKey) {
                PDFViewerApplication.findBar.open();
                handled = true;
              }
              break;
            case 71:
              if (!PDFViewerApplication.supportsIntegratedFind) {
                const {
                  state
                } = PDFViewerApplication.findController;
                if (state) {
                  const eventState = Object.assign(/* @__PURE__ */ Object.create(null), state, {
                    source: window,
                    type: "again",
                    findPrevious: cmd === 5 || cmd === 12
                  });
                  eventBus.dispatch("find", eventState);
                }
                handled = true;
              }
              break;
            case 61:
            case 107:
            case 187:
            case 171:
              if (!isViewerInPresentationMode) {
                PDFViewerApplication.zoomIn();
              }
              handled = true;
              break;
            case 173:
            case 109:
            case 189:
              if (!isViewerInPresentationMode) {
                PDFViewerApplication.zoomOut();
              }
              handled = true;
              break;
            case 48:
            case 96:
              if (!isViewerInPresentationMode) {
                setTimeout(function() {
                  PDFViewerApplication.zoomReset();
                });
                handled = false;
              }
              break;
            case 38:
              if (isViewerInPresentationMode || PDFViewerApplication.page > 1) {
                PDFViewerApplication.page = 1;
                handled = true;
                ensureViewerFocused = true;
              }
              break;
            case 40:
              if (isViewerInPresentationMode || PDFViewerApplication.page < PDFViewerApplication.pagesCount) {
                PDFViewerApplication.page = PDFViewerApplication.pagesCount;
                handled = true;
                ensureViewerFocused = true;
              }
              break;
          }
        }
        if (cmd === 1 || cmd === 8) {
          switch (evt.keyCode) {
            case 83:
              eventBus.dispatch("download", {
                source: window
              });
              handled = true;
              break;
            case 79:
              {
                eventBus.dispatch("openfile", {
                  source: window
                });
                handled = true;
              }
              break;
          }
        }
        if (cmd === 3 || cmd === 10) {
          switch (evt.keyCode) {
            case 80:
              PDFViewerApplication.requestPresentationMode();
              handled = true;
              break;
            case 71:
              PDFViewerApplication.appConfig.toolbar.pageNumber.select();
              handled = true;
              break;
          }
        }
        if (handled) {
          if (ensureViewerFocused && !isViewerInPresentationMode) {
            pdfViewer.focus();
          }
          evt.preventDefault();
          return;
        }
        const curElement = (0, _ui_utils.getActiveOrFocusedElement)();
        const curElementTagName = curElement == null ? void 0 : curElement.tagName.toUpperCase();
        if (curElementTagName === "INPUT" || curElementTagName === "TEXTAREA" || curElementTagName === "SELECT" || (curElement == null ? void 0 : curElement.isContentEditable)) {
          if (evt.keyCode !== 27) {
            return;
          }
        }
        if (cmd === 0) {
          let turnPage = 0, turnOnlyIfPageFit = false;
          switch (evt.keyCode) {
            case 38:
            case 33:
              if (pdfViewer.isVerticalScrollbarEnabled) {
                turnOnlyIfPageFit = true;
              }
              turnPage = -1;
              break;
            case 8:
              if (!isViewerInPresentationMode) {
                turnOnlyIfPageFit = true;
              }
              turnPage = -1;
              break;
            case 37:
              if (pdfViewer.isHorizontalScrollbarEnabled) {
                turnOnlyIfPageFit = true;
              }
            case 75:
            case 80:
              turnPage = -1;
              break;
            case 27:
              if (PDFViewerApplication.secondaryToolbar.isOpen) {
                PDFViewerApplication.secondaryToolbar.close();
                handled = true;
              }
              if (!PDFViewerApplication.supportsIntegratedFind && PDFViewerApplication.findBar.opened) {
                PDFViewerApplication.findBar.close();
                handled = true;
              }
              break;
            case 40:
            case 34:
              if (pdfViewer.isVerticalScrollbarEnabled) {
                turnOnlyIfPageFit = true;
              }
              turnPage = 1;
              break;
            case 13:
            case 32:
              if (!isViewerInPresentationMode) {
                turnOnlyIfPageFit = true;
              }
              turnPage = 1;
              break;
            case 39:
              if (pdfViewer.isHorizontalScrollbarEnabled) {
                turnOnlyIfPageFit = true;
              }
            case 74:
            case 78:
              turnPage = 1;
              break;
            case 36:
              if (isViewerInPresentationMode || PDFViewerApplication.page > 1) {
                PDFViewerApplication.page = 1;
                handled = true;
                ensureViewerFocused = true;
              }
              break;
            case 35:
              if (isViewerInPresentationMode || PDFViewerApplication.page < PDFViewerApplication.pagesCount) {
                PDFViewerApplication.page = PDFViewerApplication.pagesCount;
                handled = true;
                ensureViewerFocused = true;
              }
              break;
            case 83:
              PDFViewerApplication.pdfCursorTools.switchTool(_pdf_cursor_tools.CursorTool.SELECT);
              break;
            case 72:
              PDFViewerApplication.pdfCursorTools.switchTool(_pdf_cursor_tools.CursorTool.HAND);
              break;
            case 82:
              PDFViewerApplication.rotatePages(90);
              break;
            case 115:
              PDFViewerApplication.pdfSidebar.toggle();
              break;
          }
          if (turnPage !== 0 && (!turnOnlyIfPageFit || pdfViewer.currentScaleValue === "page-fit")) {
            if (turnPage > 0) {
              pdfViewer.nextPage();
            } else {
              pdfViewer.previousPage();
            }
            handled = true;
          }
        }
        if (cmd === 4) {
          switch (evt.keyCode) {
            case 13:
            case 32:
              if (!isViewerInPresentationMode && pdfViewer.currentScaleValue !== "page-fit") {
                break;
              }
              pdfViewer.previousPage();
              handled = true;
              break;
            case 82:
              PDFViewerApplication.rotatePages(-90);
              break;
          }
        }
        if (!handled && !isViewerInPresentationMode) {
          if (evt.keyCode >= 33 && evt.keyCode <= 40 || evt.keyCode === 32 && curElementTagName !== "BUTTON") {
            ensureViewerFocused = true;
          }
        }
        if (ensureViewerFocused && !pdfViewer.containsElement(curElement)) {
          pdfViewer.focus();
        }
        if (handled) {
          evt.preventDefault();
        }
      }
      function beforeUnload(evt) {
        evt.preventDefault();
        evt.returnValue = "";
        return false;
      }
      function webViewerAnnotationEditorStatesChanged(data) {
        PDFViewerApplication.externalServices.updateEditorStates(data);
      }
      const PDFPrintServiceFactory = {
        instance: {
          supportsPrinting: false,
          createPrintService() {
            throw new Error("Not implemented: createPrintService");
          }
        }
      };
      exports.PDFPrintServiceFactory = PDFPrintServiceFactory;
    }),
    /* 5 */
    /***/
    ((module) => {
      let pdfjsLib;
      if (typeof window !== "undefined" && window["pdfjs-dist/build/pdf"]) {
        pdfjsLib = window["pdfjs-dist/build/pdf"];
      } else {
        pdfjsLib = require("../build/pdf.js");
      }
      module.exports = pdfjsLib;
    }),
    /* 6 */
    /***/
    ((__unused_webpack_module, exports) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.WaitOnType = exports.EventBus = exports.AutomationEventBus = void 0;
      exports.waitOnEventOrTimeout = waitOnEventOrTimeout;
      const WaitOnType = {
        EVENT: "event",
        TIMEOUT: "timeout"
      };
      exports.WaitOnType = WaitOnType;
      function waitOnEventOrTimeout({
        target,
        name,
        delay = 0
      }) {
        return new Promise(function(resolve, reject) {
          if (typeof target !== "object" || !(name && typeof name === "string") || !(Number.isInteger(delay) && delay >= 0)) {
            throw new Error("waitOnEventOrTimeout - invalid parameters.");
          }
          function handler(type) {
            if (target instanceof EventBus) {
              target._off(name, eventHandler);
            } else {
              target.removeEventListener(name, eventHandler);
            }
            if (timeout) {
              clearTimeout(timeout);
            }
            resolve(type);
          }
          const eventHandler = handler.bind(null, WaitOnType.EVENT);
          if (target instanceof EventBus) {
            target._on(name, eventHandler);
          } else {
            target.addEventListener(name, eventHandler);
          }
          const timeoutHandler = handler.bind(null, WaitOnType.TIMEOUT);
          const timeout = setTimeout(timeoutHandler, delay);
        });
      }
      class EventBus {
        constructor() {
          this._listeners = /* @__PURE__ */ Object.create(null);
        }
        on(eventName, listener, options = null) {
          this._on(eventName, listener, {
            external: true,
            once: options == null ? void 0 : options.once
          });
        }
        off(eventName, listener, options = null) {
          this._off(eventName, listener, {
            external: true,
            once: options == null ? void 0 : options.once
          });
        }
        dispatch(eventName, data) {
          const eventListeners = this._listeners[eventName];
          if (!eventListeners || eventListeners.length === 0) {
            return;
          }
          let externalListeners;
          for (const {
            listener,
            external,
            once
          } of eventListeners.slice(0)) {
            if (once) {
              this._off(eventName, listener);
            }
            if (external) {
              (externalListeners || (externalListeners = [])).push(listener);
              continue;
            }
            listener(data);
          }
          if (externalListeners) {
            for (const listener of externalListeners) {
              listener(data);
            }
            externalListeners = null;
          }
        }
        _on(eventName, listener, options = null) {
          var _a;
          const eventListeners = (_a = this._listeners)[eventName] || (_a[eventName] = []);
          eventListeners.push({
            listener,
            external: (options == null ? void 0 : options.external) === true,
            once: (options == null ? void 0 : options.once) === true
          });
        }
        _off(eventName, listener, options = null) {
          const eventListeners = this._listeners[eventName];
          if (!eventListeners) {
            return;
          }
          for (let i = 0, ii = eventListeners.length; i < ii; i++) {
            if (eventListeners[i].listener === listener) {
              eventListeners.splice(i, 1);
              return;
            }
          }
        }
      }
      exports.EventBus = EventBus;
      class AutomationEventBus extends EventBus {
        dispatch(eventName, data) {
          throw new Error("Not implemented: AutomationEventBus.dispatch");
        }
      }
      exports.AutomationEventBus = AutomationEventBus;
    }),
    /* 7 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _PDFCursorTools_instances, dispatchEvent_fn, addEventListeners_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFCursorTools = exports.CursorTool = void 0;
      var _grab_to_pan = __webpack_require__2(8);
      var _ui_utils = __webpack_require__2(1);
      const CursorTool = {
        SELECT: 0,
        HAND: 1,
        ZOOM: 2
      };
      exports.CursorTool = CursorTool;
      class PDFCursorTools {
        constructor({
          container,
          eventBus,
          cursorToolOnLoad = CursorTool.SELECT
        }) {
          __privateAdd(this, _PDFCursorTools_instances);
          this.container = container;
          this.eventBus = eventBus;
          this.active = CursorTool.SELECT;
          this.activeBeforePresentationMode = null;
          this.handTool = new _grab_to_pan.GrabToPan({
            element: this.container
          });
          __privateMethod(this, _PDFCursorTools_instances, addEventListeners_fn).call(this);
          Promise.resolve().then(() => {
            this.switchTool(cursorToolOnLoad);
          });
        }
        get activeTool() {
          return this.active;
        }
        switchTool(tool) {
          if (this.activeBeforePresentationMode !== null) {
            return;
          }
          if (tool === this.active) {
            return;
          }
          const disableActiveTool = () => {
            switch (this.active) {
              case CursorTool.SELECT:
                break;
              case CursorTool.HAND:
                this.handTool.deactivate();
                break;
              case CursorTool.ZOOM:
            }
          };
          switch (tool) {
            case CursorTool.SELECT:
              disableActiveTool();
              break;
            case CursorTool.HAND:
              disableActiveTool();
              this.handTool.activate();
              break;
            case CursorTool.ZOOM:
            default:
              console.error(`switchTool: "${tool}" is an unsupported value.`);
              return;
          }
          this.active = tool;
          __privateMethod(this, _PDFCursorTools_instances, dispatchEvent_fn).call(this);
        }
      }
      _PDFCursorTools_instances = new WeakSet();
      dispatchEvent_fn = function() {
        this.eventBus.dispatch("cursortoolchanged", {
          source: this,
          tool: this.active
        });
      };
      addEventListeners_fn = function() {
        this.eventBus._on("switchcursortool", (evt) => {
          this.switchTool(evt.tool);
        });
        this.eventBus._on("presentationmodechanged", (evt) => {
          switch (evt.state) {
            case _ui_utils.PresentationModeState.FULLSCREEN: {
              const previouslyActive = this.active;
              this.switchTool(CursorTool.SELECT);
              this.activeBeforePresentationMode = previouslyActive;
              break;
            }
            case _ui_utils.PresentationModeState.NORMAL: {
              const previouslyActive = this.activeBeforePresentationMode;
              this.activeBeforePresentationMode = null;
              this.switchTool(previouslyActive);
              break;
            }
          }
        });
      };
      exports.PDFCursorTools = PDFCursorTools;
    }),
    /* 8 */
    /***/
    ((__unused_webpack_module, exports) => {
      var _GrabToPan_instances, onMouseDown_fn, onMouseMove_fn, endPan_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.GrabToPan = void 0;
      const CSS_CLASS_GRAB = "grab-to-pan-grab";
      class GrabToPan {
        constructor(options) {
          __privateAdd(this, _GrabToPan_instances);
          this.element = options.element;
          this.document = options.element.ownerDocument;
          if (typeof options.ignoreTarget === "function") {
            this.ignoreTarget = options.ignoreTarget;
          }
          this.onActiveChanged = options.onActiveChanged;
          this.activate = this.activate.bind(this);
          this.deactivate = this.deactivate.bind(this);
          this.toggle = this.toggle.bind(this);
          this._onMouseDown = __privateMethod(this, _GrabToPan_instances, onMouseDown_fn).bind(this);
          this._onMouseMove = __privateMethod(this, _GrabToPan_instances, onMouseMove_fn).bind(this);
          this._endPan = __privateMethod(this, _GrabToPan_instances, endPan_fn).bind(this);
          const overlay = this.overlay = document.createElement("div");
          overlay.className = "grab-to-pan-grabbing";
        }
        activate() {
          var _a;
          if (!this.active) {
            this.active = true;
            this.element.addEventListener("mousedown", this._onMouseDown, true);
            this.element.classList.add(CSS_CLASS_GRAB);
            (_a = this.onActiveChanged) == null ? void 0 : _a.call(this, true);
          }
        }
        deactivate() {
          var _a;
          if (this.active) {
            this.active = false;
            this.element.removeEventListener("mousedown", this._onMouseDown, true);
            this._endPan();
            this.element.classList.remove(CSS_CLASS_GRAB);
            (_a = this.onActiveChanged) == null ? void 0 : _a.call(this, false);
          }
        }
        toggle() {
          if (this.active) {
            this.deactivate();
          } else {
            this.activate();
          }
        }
        ignoreTarget(node) {
          return node.matches("a[href], a[href] *, input, textarea, button, button *, select, option");
        }
      }
      _GrabToPan_instances = new WeakSet();
      onMouseDown_fn = function(event) {
        if (event.button !== 0 || this.ignoreTarget(event.target)) {
          return;
        }
        if (event.originalTarget) {
          try {
            event.originalTarget.tagName;
          } catch (e) {
            return;
          }
        }
        this.scrollLeftStart = this.element.scrollLeft;
        this.scrollTopStart = this.element.scrollTop;
        this.clientXStart = event.clientX;
        this.clientYStart = event.clientY;
        this.document.addEventListener("mousemove", this._onMouseMove, true);
        this.document.addEventListener("mouseup", this._endPan, true);
        this.element.addEventListener("scroll", this._endPan, true);
        event.preventDefault();
        event.stopPropagation();
        const focusedElement = document.activeElement;
        if (focusedElement && !focusedElement.contains(event.target)) {
          focusedElement.blur();
        }
      };
      onMouseMove_fn = function(event) {
        this.element.removeEventListener("scroll", this._endPan, true);
        if (!(event.buttons & 1)) {
          this._endPan();
          return;
        }
        const xDiff = event.clientX - this.clientXStart;
        const yDiff = event.clientY - this.clientYStart;
        const scrollTop = this.scrollTopStart - yDiff;
        const scrollLeft = this.scrollLeftStart - xDiff;
        if (this.element.scrollTo) {
          this.element.scrollTo({
            top: scrollTop,
            left: scrollLeft,
            behavior: "instant"
          });
        } else {
          this.element.scrollTop = scrollTop;
          this.element.scrollLeft = scrollLeft;
        }
        if (!this.overlay.parentNode) {
          document.body.append(this.overlay);
        }
      };
      endPan_fn = function() {
        this.element.removeEventListener("scroll", this._endPan, true);
        this.document.removeEventListener("mousemove", this._onMouseMove, true);
        this.document.removeEventListener("mouseup", this._endPan, true);
        this.overlay.remove();
      };
      exports.GrabToPan = GrabToPan;
    }),
    /* 9 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _AnnotationEditorParams_instances, bindListeners_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.AnnotationEditorParams = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      class AnnotationEditorParams {
        constructor(options, eventBus) {
          __privateAdd(this, _AnnotationEditorParams_instances);
          this.eventBus = eventBus;
          __privateMethod(this, _AnnotationEditorParams_instances, bindListeners_fn).call(this, options);
        }
      }
      _AnnotationEditorParams_instances = new WeakSet();
      bindListeners_fn = function({
        editorFreeTextFontSize,
        editorFreeTextColor,
        editorInkColor,
        editorInkThickness,
        editorInkOpacity
      }) {
        editorFreeTextFontSize.addEventListener("input", (evt) => {
          this.eventBus.dispatch("switchannotationeditorparams", {
            source: this,
            type: _pdfjsLib.AnnotationEditorParamsType.FREETEXT_SIZE,
            value: editorFreeTextFontSize.valueAsNumber
          });
        });
        editorFreeTextColor.addEventListener("input", (evt) => {
          this.eventBus.dispatch("switchannotationeditorparams", {
            source: this,
            type: _pdfjsLib.AnnotationEditorParamsType.FREETEXT_COLOR,
            value: editorFreeTextColor.value
          });
        });
        editorInkColor.addEventListener("input", (evt) => {
          this.eventBus.dispatch("switchannotationeditorparams", {
            source: this,
            type: _pdfjsLib.AnnotationEditorParamsType.INK_COLOR,
            value: editorInkColor.value
          });
        });
        editorInkThickness.addEventListener("input", (evt) => {
          this.eventBus.dispatch("switchannotationeditorparams", {
            source: this,
            type: _pdfjsLib.AnnotationEditorParamsType.INK_THICKNESS,
            value: editorInkThickness.valueAsNumber
          });
        });
        editorInkOpacity.addEventListener("input", (evt) => {
          this.eventBus.dispatch("switchannotationeditorparams", {
            source: this,
            type: _pdfjsLib.AnnotationEditorParamsType.INK_OPACITY,
            value: editorInkOpacity.valueAsNumber
          });
        });
        this.eventBus._on("annotationeditorparamschanged", (evt) => {
          for (const [type, value] of evt.details) {
            switch (type) {
              case _pdfjsLib.AnnotationEditorParamsType.FREETEXT_SIZE:
                editorFreeTextFontSize.value = value;
                break;
              case _pdfjsLib.AnnotationEditorParamsType.FREETEXT_COLOR:
                editorFreeTextColor.value = value;
                break;
              case _pdfjsLib.AnnotationEditorParamsType.INK_COLOR:
                editorInkColor.value = value;
                break;
              case _pdfjsLib.AnnotationEditorParamsType.INK_THICKNESS:
                editorInkThickness.value = value;
                break;
              case _pdfjsLib.AnnotationEditorParamsType.INK_OPACITY:
                editorInkOpacity.value = value;
                break;
            }
          }
        });
      };
      exports.AnnotationEditorParams = AnnotationEditorParams;
    }),
    /* 10 */
    /***/
    ((__unused_webpack_module, exports) => {
      var _overlays, _active;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.OverlayManager = void 0;
      class OverlayManager {
        constructor() {
          __privateAdd(this, _overlays, /* @__PURE__ */ new WeakMap());
          __privateAdd(this, _active, null);
        }
        get active() {
          return __privateGet(this, _active);
        }
        async register(dialog, canForceClose = false) {
          if (typeof dialog !== "object") {
            throw new Error("Not enough parameters.");
          } else if (__privateGet(this, _overlays).has(dialog)) {
            throw new Error("The overlay is already registered.");
          }
          __privateGet(this, _overlays).set(dialog, {
            canForceClose
          });
          dialog.addEventListener("cancel", (evt) => {
            __privateSet(this, _active, null);
          });
        }
        async unregister(dialog) {
          if (!__privateGet(this, _overlays).has(dialog)) {
            throw new Error("The overlay does not exist.");
          } else if (__privateGet(this, _active) === dialog) {
            throw new Error("The overlay cannot be removed while it is active.");
          }
          __privateGet(this, _overlays).delete(dialog);
        }
        async open(dialog) {
          if (!__privateGet(this, _overlays).has(dialog)) {
            throw new Error("The overlay does not exist.");
          } else if (__privateGet(this, _active)) {
            if (__privateGet(this, _active) === dialog) {
              throw new Error("The overlay is already active.");
            } else if (__privateGet(this, _overlays).get(dialog).canForceClose) {
              await this.close();
            } else {
              throw new Error("Another overlay is currently active.");
            }
          }
          __privateSet(this, _active, dialog);
          dialog.showModal();
        }
        async close(dialog = __privateGet(this, _active)) {
          if (!__privateGet(this, _overlays).has(dialog)) {
            throw new Error("The overlay does not exist.");
          } else if (!__privateGet(this, _active)) {
            throw new Error("The overlay is currently not active.");
          } else if (__privateGet(this, _active) !== dialog) {
            throw new Error("Another overlay is currently active.");
          }
          dialog.close();
          __privateSet(this, _active, null);
        }
      }
      _overlays = new WeakMap();
      _active = new WeakMap();
      exports.OverlayManager = OverlayManager;
    }),
    /* 11 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _activeCapability, _updateCallback, _reason, _PasswordPrompt_instances, verify_fn, cancel_fn, invokeCallback_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PasswordPrompt = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      class PasswordPrompt {
        constructor(options, overlayManager, l10n, isViewerEmbedded = false) {
          __privateAdd(this, _PasswordPrompt_instances);
          __privateAdd(this, _activeCapability, null);
          __privateAdd(this, _updateCallback, null);
          __privateAdd(this, _reason, null);
          this.dialog = options.dialog;
          this.label = options.label;
          this.input = options.input;
          this.submitButton = options.submitButton;
          this.cancelButton = options.cancelButton;
          this.overlayManager = overlayManager;
          this.l10n = l10n;
          this._isViewerEmbedded = isViewerEmbedded;
          this.submitButton.addEventListener("click", __privateMethod(this, _PasswordPrompt_instances, verify_fn).bind(this));
          this.cancelButton.addEventListener("click", this.close.bind(this));
          this.input.addEventListener("keydown", (e) => {
            if (e.keyCode === 13) {
              __privateMethod(this, _PasswordPrompt_instances, verify_fn).call(this);
            }
          });
          this.overlayManager.register(this.dialog, true);
          this.dialog.addEventListener("close", __privateMethod(this, _PasswordPrompt_instances, cancel_fn).bind(this));
        }
        async open() {
          if (__privateGet(this, _activeCapability)) {
            await __privateGet(this, _activeCapability).promise;
          }
          __privateSet(this, _activeCapability, (0, _pdfjsLib.createPromiseCapability)());
          try {
            await this.overlayManager.open(this.dialog);
          } catch (ex) {
            __privateSet(this, _activeCapability, null);
            throw ex;
          }
          const passwordIncorrect = __privateGet(this, _reason) === _pdfjsLib.PasswordResponses.INCORRECT_PASSWORD;
          if (!this._isViewerEmbedded || passwordIncorrect) {
            this.input.focus();
          }
          this.label.textContent = await this.l10n.get(`password_${passwordIncorrect ? "invalid" : "label"}`);
        }
        async close() {
          if (this.overlayManager.active === this.dialog) {
            this.overlayManager.close(this.dialog);
          }
        }
        async setUpdateCallback(updateCallback, reason) {
          if (__privateGet(this, _activeCapability)) {
            await __privateGet(this, _activeCapability).promise;
          }
          __privateSet(this, _updateCallback, updateCallback);
          __privateSet(this, _reason, reason);
        }
      }
      _activeCapability = new WeakMap();
      _updateCallback = new WeakMap();
      _reason = new WeakMap();
      _PasswordPrompt_instances = new WeakSet();
      verify_fn = function() {
        const password = this.input.value;
        if ((password == null ? void 0 : password.length) > 0) {
          __privateMethod(this, _PasswordPrompt_instances, invokeCallback_fn).call(this, password);
        }
      };
      cancel_fn = function() {
        __privateMethod(this, _PasswordPrompt_instances, invokeCallback_fn).call(this, new Error("PasswordPrompt cancelled."));
        __privateGet(this, _activeCapability).resolve();
      };
      invokeCallback_fn = function(password) {
        if (!__privateGet(this, _updateCallback)) {
          return;
        }
        this.close();
        this.input.value = "";
        __privateGet(this, _updateCallback).call(this, password);
        __privateSet(this, _updateCallback, null);
      };
      exports.PasswordPrompt = PasswordPrompt;
    }),
    /* 12 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _PDFAttachmentViewer_instances, appendAttachment_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFAttachmentViewer = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      var _base_tree_viewer = __webpack_require__2(13);
      var _event_utils = __webpack_require__2(6);
      class PDFAttachmentViewer extends _base_tree_viewer.BaseTreeViewer {
        constructor(options) {
          super(options);
          __privateAdd(this, _PDFAttachmentViewer_instances);
          this.downloadManager = options.downloadManager;
          this.eventBus._on("fileattachmentannotation", __privateMethod(this, _PDFAttachmentViewer_instances, appendAttachment_fn).bind(this));
        }
        reset(keepRenderedCapability = false) {
          super.reset();
          this._attachments = null;
          if (!keepRenderedCapability) {
            this._renderedCapability = (0, _pdfjsLib.createPromiseCapability)();
          }
          this._pendingDispatchEvent = false;
        }
        async _dispatchEvent(attachmentsCount) {
          this._renderedCapability.resolve();
          if (attachmentsCount === 0 && !this._pendingDispatchEvent) {
            this._pendingDispatchEvent = true;
            await (0, _event_utils.waitOnEventOrTimeout)({
              target: this.eventBus,
              name: "annotationlayerrendered",
              delay: 1e3
            });
            if (!this._pendingDispatchEvent) {
              return;
            }
          }
          this._pendingDispatchEvent = false;
          this.eventBus.dispatch("attachmentsloaded", {
            source: this,
            attachmentsCount
          });
        }
        _bindLink(element, {
          content,
          filename
        }) {
          element.onclick = () => {
            this.downloadManager.openOrDownloadData(element, content, filename);
            return false;
          };
        }
        render({
          attachments,
          keepRenderedCapability = false
        }) {
          if (this._attachments) {
            this.reset(keepRenderedCapability);
          }
          this._attachments = attachments || null;
          if (!attachments) {
            this._dispatchEvent(0);
            return;
          }
          const names = Object.keys(attachments).sort(function(a, b) {
            return a.toLowerCase().localeCompare(b.toLowerCase());
          });
          const fragment = document.createDocumentFragment();
          let attachmentsCount = 0;
          for (const name of names) {
            const item = attachments[name];
            const content = item.content, filename = (0, _pdfjsLib.getFilenameFromUrl)(item.filename);
            const div = document.createElement("div");
            div.className = "treeItem";
            const element = document.createElement("a");
            this._bindLink(element, {
              content,
              filename
            });
            element.textContent = this._normalizeTextContent(filename);
            div.append(element);
            fragment.append(div);
            attachmentsCount++;
          }
          this._finishRendering(fragment, attachmentsCount);
        }
      }
      _PDFAttachmentViewer_instances = new WeakSet();
      appendAttachment_fn = function({
        filename,
        content
      }) {
        const renderedPromise = this._renderedCapability.promise;
        renderedPromise.then(() => {
          if (renderedPromise !== this._renderedCapability.promise) {
            return;
          }
          const attachments = this._attachments || /* @__PURE__ */ Object.create(null);
          for (const name in attachments) {
            if (filename === name) {
              return;
            }
          }
          attachments[filename] = {
            filename,
            content
          };
          this.render({
            attachments,
            keepRenderedCapability: true
          });
        });
      };
      exports.PDFAttachmentViewer = PDFAttachmentViewer;
    }),
    /* 13 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.BaseTreeViewer = void 0;
      var _ui_utils = __webpack_require__2(1);
      const TREEITEM_OFFSET_TOP = -100;
      const TREEITEM_SELECTED_CLASS = "selected";
      class BaseTreeViewer {
        constructor(options) {
          if (this.constructor === BaseTreeViewer) {
            throw new Error("Cannot initialize BaseTreeViewer.");
          }
          this.container = options.container;
          this.eventBus = options.eventBus;
          this.reset();
        }
        reset() {
          this._pdfDocument = null;
          this._lastToggleIsShow = true;
          this._currentTreeItem = null;
          this.container.textContent = "";
          this.container.classList.remove("treeWithDeepNesting");
        }
        _dispatchEvent(count) {
          throw new Error("Not implemented: _dispatchEvent");
        }
        _bindLink(element, params) {
          throw new Error("Not implemented: _bindLink");
        }
        _normalizeTextContent(str) {
          return (0, _ui_utils.removeNullCharacters)(str, true) || "\u2013";
        }
        _addToggleButton(div, hidden = false) {
          const toggler = document.createElement("div");
          toggler.className = "treeItemToggler";
          if (hidden) {
            toggler.classList.add("treeItemsHidden");
          }
          toggler.onclick = (evt) => {
            evt.stopPropagation();
            toggler.classList.toggle("treeItemsHidden");
            if (evt.shiftKey) {
              const shouldShowAll = !toggler.classList.contains("treeItemsHidden");
              this._toggleTreeItem(div, shouldShowAll);
            }
          };
          div.prepend(toggler);
        }
        _toggleTreeItem(root, show = false) {
          this._lastToggleIsShow = show;
          for (const toggler of root.querySelectorAll(".treeItemToggler")) {
            toggler.classList.toggle("treeItemsHidden", !show);
          }
        }
        _toggleAllTreeItems() {
          this._toggleTreeItem(this.container, !this._lastToggleIsShow);
        }
        _finishRendering(fragment, count, hasAnyNesting = false) {
          if (hasAnyNesting) {
            this.container.classList.add("treeWithDeepNesting");
            this._lastToggleIsShow = !fragment.querySelector(".treeItemsHidden");
          }
          this.container.append(fragment);
          this._dispatchEvent(count);
        }
        render(params) {
          throw new Error("Not implemented: render");
        }
        _updateCurrentTreeItem(treeItem = null) {
          if (this._currentTreeItem) {
            this._currentTreeItem.classList.remove(TREEITEM_SELECTED_CLASS);
            this._currentTreeItem = null;
          }
          if (treeItem) {
            treeItem.classList.add(TREEITEM_SELECTED_CLASS);
            this._currentTreeItem = treeItem;
          }
        }
        _scrollToCurrentTreeItem(treeItem) {
          if (!treeItem) {
            return;
          }
          let currentNode = treeItem.parentNode;
          while (currentNode && currentNode !== this.container) {
            if (currentNode.classList.contains("treeItem")) {
              const toggler = currentNode.firstElementChild;
              toggler == null ? void 0 : toggler.classList.remove("treeItemsHidden");
            }
            currentNode = currentNode.parentNode;
          }
          this._updateCurrentTreeItem(treeItem);
          this.container.scrollTo(treeItem.offsetLeft, treeItem.offsetTop + TREEITEM_OFFSET_TOP);
        }
      }
      exports.BaseTreeViewer = BaseTreeViewer;
    }),
    /* 14 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _fieldData, _PDFDocumentProperties_instances, reset_fn, updateUI_fn, parseFileSize_fn, parsePageSize_fn, parseDate_fn, parseLinearization_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFDocumentProperties = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      var _ui_utils = __webpack_require__2(1);
      const DEFAULT_FIELD_CONTENT = "-";
      const NON_METRIC_LOCALES = ["en-us", "en-lr", "my"];
      const US_PAGE_NAMES = {
        "8.5x11": "Letter",
        "8.5x14": "Legal"
      };
      const METRIC_PAGE_NAMES = {
        "297x420": "A3",
        "210x297": "A4"
      };
      function getPageName(size, isPortrait, pageNames) {
        const width = isPortrait ? size.width : size.height;
        const height = isPortrait ? size.height : size.width;
        return pageNames[`${width}x${height}`];
      }
      class PDFDocumentProperties {
        constructor({
          dialog,
          fields,
          closeButton
        }, overlayManager, eventBus, l10n, fileNameLookup) {
          __privateAdd(this, _PDFDocumentProperties_instances);
          __privateAdd(this, _fieldData, null);
          this.dialog = dialog;
          this.fields = fields;
          this.overlayManager = overlayManager;
          this.l10n = l10n;
          this._fileNameLookup = fileNameLookup;
          __privateMethod(this, _PDFDocumentProperties_instances, reset_fn).call(this);
          closeButton.addEventListener("click", this.close.bind(this));
          this.overlayManager.register(this.dialog);
          eventBus._on("pagechanging", (evt) => {
            this._currentPageNumber = evt.pageNumber;
          });
          eventBus._on("rotationchanging", (evt) => {
            this._pagesRotation = evt.pagesRotation;
          });
          this._isNonMetricLocale = true;
          l10n.getLanguage().then((locale) => {
            this._isNonMetricLocale = NON_METRIC_LOCALES.includes(locale);
          });
        }
        async open() {
          await Promise.all([this.overlayManager.open(this.dialog), this._dataAvailableCapability.promise]);
          const currentPageNumber = this._currentPageNumber;
          const pagesRotation = this._pagesRotation;
          if (__privateGet(this, _fieldData) && currentPageNumber === __privateGet(this, _fieldData)._currentPageNumber && pagesRotation === __privateGet(this, _fieldData)._pagesRotation) {
            __privateMethod(this, _PDFDocumentProperties_instances, updateUI_fn).call(this);
            return;
          }
          const {
            info,
            contentLength
          } = await this.pdfDocument.getMetadata();
          const [fileName, fileSize, creationDate, modificationDate, pageSize, isLinearized] = await Promise.all([this._fileNameLookup(), __privateMethod(this, _PDFDocumentProperties_instances, parseFileSize_fn).call(this, contentLength), __privateMethod(this, _PDFDocumentProperties_instances, parseDate_fn).call(this, info.CreationDate), __privateMethod(this, _PDFDocumentProperties_instances, parseDate_fn).call(this, info.ModDate), this.pdfDocument.getPage(currentPageNumber).then((pdfPage) => {
            return __privateMethod(this, _PDFDocumentProperties_instances, parsePageSize_fn).call(this, (0, _ui_utils.getPageSizeInches)(pdfPage), pagesRotation);
          }), __privateMethod(this, _PDFDocumentProperties_instances, parseLinearization_fn).call(this, info.IsLinearized)]);
          __privateSet(this, _fieldData, Object.freeze({
            fileName,
            fileSize,
            title: info.Title,
            author: info.Author,
            subject: info.Subject,
            keywords: info.Keywords,
            creationDate,
            modificationDate,
            creator: info.Creator,
            producer: info.Producer,
            version: info.PDFFormatVersion,
            pageCount: this.pdfDocument.numPages,
            pageSize,
            linearized: isLinearized,
            _currentPageNumber: currentPageNumber,
            _pagesRotation: pagesRotation
          }));
          __privateMethod(this, _PDFDocumentProperties_instances, updateUI_fn).call(this);
          const {
            length
          } = await this.pdfDocument.getDownloadInfo();
          if (contentLength === length) {
            return;
          }
          const data = Object.assign(/* @__PURE__ */ Object.create(null), __privateGet(this, _fieldData));
          data.fileSize = await __privateMethod(this, _PDFDocumentProperties_instances, parseFileSize_fn).call(this, length);
          __privateSet(this, _fieldData, Object.freeze(data));
          __privateMethod(this, _PDFDocumentProperties_instances, updateUI_fn).call(this);
        }
        async close() {
          this.overlayManager.close(this.dialog);
        }
        setDocument(pdfDocument) {
          if (this.pdfDocument) {
            __privateMethod(this, _PDFDocumentProperties_instances, reset_fn).call(this);
            __privateMethod(this, _PDFDocumentProperties_instances, updateUI_fn).call(this, true);
          }
          if (!pdfDocument) {
            return;
          }
          this.pdfDocument = pdfDocument;
          this._dataAvailableCapability.resolve();
        }
      }
      _fieldData = new WeakMap();
      _PDFDocumentProperties_instances = new WeakSet();
      reset_fn = function() {
        this.pdfDocument = null;
        __privateSet(this, _fieldData, null);
        this._dataAvailableCapability = (0, _pdfjsLib.createPromiseCapability)();
        this._currentPageNumber = 1;
        this._pagesRotation = 0;
      };
      updateUI_fn = function(reset = false) {
        if (reset || !__privateGet(this, _fieldData)) {
          for (const id in this.fields) {
            this.fields[id].textContent = DEFAULT_FIELD_CONTENT;
          }
          return;
        }
        if (this.overlayManager.active !== this.dialog) {
          return;
        }
        for (const id in this.fields) {
          const content = __privateGet(this, _fieldData)[id];
          this.fields[id].textContent = content || content === 0 ? content : DEFAULT_FIELD_CONTENT;
        }
      };
      parseFileSize_fn = async function(fileSize = 0) {
        const kb = fileSize / 1024, mb = kb / 1024;
        if (!kb) {
          return void 0;
        }
        return this.l10n.get(`document_properties_${mb >= 1 ? "mb" : "kb"}`, {
          size_mb: mb >= 1 && (+mb.toPrecision(3)).toLocaleString(),
          size_kb: mb < 1 && (+kb.toPrecision(3)).toLocaleString(),
          size_b: fileSize.toLocaleString()
        });
      };
      parsePageSize_fn = async function(pageSizeInches, pagesRotation) {
        if (!pageSizeInches) {
          return void 0;
        }
        if (pagesRotation % 180 !== 0) {
          pageSizeInches = {
            width: pageSizeInches.height,
            height: pageSizeInches.width
          };
        }
        const isPortrait = (0, _ui_utils.isPortraitOrientation)(pageSizeInches);
        let sizeInches = {
          width: Math.round(pageSizeInches.width * 100) / 100,
          height: Math.round(pageSizeInches.height * 100) / 100
        };
        let sizeMillimeters = {
          width: Math.round(pageSizeInches.width * 25.4 * 10) / 10,
          height: Math.round(pageSizeInches.height * 25.4 * 10) / 10
        };
        let rawName = getPageName(sizeInches, isPortrait, US_PAGE_NAMES) || getPageName(sizeMillimeters, isPortrait, METRIC_PAGE_NAMES);
        if (!rawName && !(Number.isInteger(sizeMillimeters.width) && Number.isInteger(sizeMillimeters.height))) {
          const exactMillimeters = {
            width: pageSizeInches.width * 25.4,
            height: pageSizeInches.height * 25.4
          };
          const intMillimeters = {
            width: Math.round(sizeMillimeters.width),
            height: Math.round(sizeMillimeters.height)
          };
          if (Math.abs(exactMillimeters.width - intMillimeters.width) < 0.1 && Math.abs(exactMillimeters.height - intMillimeters.height) < 0.1) {
            rawName = getPageName(intMillimeters, isPortrait, METRIC_PAGE_NAMES);
            if (rawName) {
              sizeInches = {
                width: Math.round(intMillimeters.width / 25.4 * 100) / 100,
                height: Math.round(intMillimeters.height / 25.4 * 100) / 100
              };
              sizeMillimeters = intMillimeters;
            }
          }
        }
        const [{
          width,
          height
        }, unit, name, orientation] = await Promise.all([this._isNonMetricLocale ? sizeInches : sizeMillimeters, this.l10n.get(`document_properties_page_size_unit_${this._isNonMetricLocale ? "inches" : "millimeters"}`), rawName && this.l10n.get(`document_properties_page_size_name_${rawName.toLowerCase()}`), this.l10n.get(`document_properties_page_size_orientation_${isPortrait ? "portrait" : "landscape"}`)]);
        return this.l10n.get(`document_properties_page_size_dimension_${name ? "name_" : ""}string`, {
          width: width.toLocaleString(),
          height: height.toLocaleString(),
          unit,
          name,
          orientation
        });
      };
      parseDate_fn = async function(inputDate) {
        const dateObject = _pdfjsLib.PDFDateString.toDateObject(inputDate);
        if (!dateObject) {
          return void 0;
        }
        return this.l10n.get("document_properties_date_string", {
          date: dateObject.toLocaleDateString(),
          time: dateObject.toLocaleTimeString()
        });
      };
      parseLinearization_fn = function(isLinearized) {
        return this.l10n.get(`document_properties_linearized_${isLinearized ? "yes" : "no"}`);
      };
      exports.PDFDocumentProperties = PDFDocumentProperties;
    }),
    /* 15 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _PDFFindBar_instances, adjustWidth_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFFindBar = void 0;
      var _pdf_find_controller = __webpack_require__2(16);
      const MATCHES_COUNT_LIMIT = 1e3;
      class PDFFindBar {
        constructor(options, eventBus, l10n) {
          __privateAdd(this, _PDFFindBar_instances);
          this.opened = false;
          this.bar = options.bar;
          this.toggleButton = options.toggleButton;
          this.findField = options.findField;
          this.highlightAll = options.highlightAllCheckbox;
          this.caseSensitive = options.caseSensitiveCheckbox;
          this.matchDiacritics = options.matchDiacriticsCheckbox;
          this.entireWord = options.entireWordCheckbox;
          this.findMsg = options.findMsg;
          this.findResultsCount = options.findResultsCount;
          this.findPreviousButton = options.findPreviousButton;
          this.findNextButton = options.findNextButton;
          this.eventBus = eventBus;
          this.l10n = l10n;
          this.toggleButton.addEventListener("click", () => {
            this.toggle();
          });
          this.findField.addEventListener("input", () => {
            this.dispatchEvent("");
          });
          this.bar.addEventListener("keydown", (e) => {
            switch (e.keyCode) {
              case 13:
                if (e.target === this.findField) {
                  this.dispatchEvent("again", e.shiftKey);
                }
                break;
              case 27:
                this.close();
                break;
            }
          });
          this.findPreviousButton.addEventListener("click", () => {
            this.dispatchEvent("again", true);
          });
          this.findNextButton.addEventListener("click", () => {
            this.dispatchEvent("again", false);
          });
          this.highlightAll.addEventListener("click", () => {
            this.dispatchEvent("highlightallchange");
          });
          this.caseSensitive.addEventListener("click", () => {
            this.dispatchEvent("casesensitivitychange");
          });
          this.entireWord.addEventListener("click", () => {
            this.dispatchEvent("entirewordchange");
          });
          this.matchDiacritics.addEventListener("click", () => {
            this.dispatchEvent("diacriticmatchingchange");
          });
          this.eventBus._on("resize", __privateMethod(this, _PDFFindBar_instances, adjustWidth_fn).bind(this));
        }
        reset() {
          this.updateUIState();
        }
        dispatchEvent(type, findPrev = false) {
          this.eventBus.dispatch("find", {
            source: this,
            type,
            query: this.findField.value,
            phraseSearch: true,
            caseSensitive: this.caseSensitive.checked,
            entireWord: this.entireWord.checked,
            highlightAll: this.highlightAll.checked,
            findPrevious: findPrev,
            matchDiacritics: this.matchDiacritics.checked
          });
        }
        updateUIState(state, previous, matchesCount) {
          let findMsg = Promise.resolve("");
          let status = "";
          switch (state) {
            case _pdf_find_controller.FindState.FOUND:
              break;
            case _pdf_find_controller.FindState.PENDING:
              status = "pending";
              break;
            case _pdf_find_controller.FindState.NOT_FOUND:
              findMsg = this.l10n.get("find_not_found");
              status = "notFound";
              break;
            case _pdf_find_controller.FindState.WRAPPED:
              findMsg = this.l10n.get(`find_reached_${previous ? "top" : "bottom"}`);
              break;
          }
          this.findField.setAttribute("data-status", status);
          this.findField.setAttribute("aria-invalid", state === _pdf_find_controller.FindState.NOT_FOUND);
          findMsg.then((msg) => {
            this.findMsg.textContent = msg;
            __privateMethod(this, _PDFFindBar_instances, adjustWidth_fn).call(this);
          });
          this.updateResultsCount(matchesCount);
        }
        updateResultsCount({
          current = 0,
          total = 0
        } = {}) {
          const limit = MATCHES_COUNT_LIMIT;
          let matchCountMsg = Promise.resolve("");
          if (total > 0) {
            if (total > limit) {
              let key = "find_match_count_limit";
              matchCountMsg = this.l10n.get(key, {
                limit
              });
            } else {
              let key = "find_match_count";
              matchCountMsg = this.l10n.get(key, {
                current,
                total
              });
            }
          }
          matchCountMsg.then((msg) => {
            this.findResultsCount.textContent = msg;
            __privateMethod(this, _PDFFindBar_instances, adjustWidth_fn).call(this);
          });
        }
        open() {
          if (!this.opened) {
            this.opened = true;
            this.toggleButton.classList.add("toggled");
            this.toggleButton.setAttribute("aria-expanded", "true");
            this.bar.classList.remove("hidden");
          }
          this.findField.select();
          this.findField.focus();
          __privateMethod(this, _PDFFindBar_instances, adjustWidth_fn).call(this);
        }
        close() {
          if (!this.opened) {
            return;
          }
          this.opened = false;
          this.toggleButton.classList.remove("toggled");
          this.toggleButton.setAttribute("aria-expanded", "false");
          this.bar.classList.add("hidden");
          this.eventBus.dispatch("findbarclose", {
            source: this
          });
        }
        toggle() {
          if (this.opened) {
            this.close();
          } else {
            this.open();
          }
        }
      }
      _PDFFindBar_instances = new WeakSet();
      adjustWidth_fn = function() {
        if (!this.opened) {
          return;
        }
        this.bar.classList.remove("wrapContainers");
        const findbarHeight = this.bar.clientHeight;
        const inputContainerHeight = this.bar.firstElementChild.clientHeight;
        if (findbarHeight > inputContainerHeight) {
          this.bar.classList.add("wrapContainers");
        }
      };
      exports.PDFFindBar = PDFFindBar;
    }),
    /* 16 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _PDFFindController_instances, onFind_fn, reset_fn, query_get, shouldDirtyMatch_fn, isEntireWord_fn, calculateRegExpMatch_fn, convertToRegExpString_fn, calculateMatch_fn, extractText_fn, updatePage_fn, updateAllPages_fn, nextMatch_fn, matchesReady_fn, nextPageMatch_fn, advanceOffsetPage_fn, updateMatch_fn, onFindBarClose_fn, requestMatchesCount_fn, updateUIResultsCount_fn, updateUIState_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFFindController = exports.FindState = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _pdfjsLib = __webpack_require__2(5);
      var _pdf_find_utils = __webpack_require__2(17);
      const FindState = {
        FOUND: 0,
        NOT_FOUND: 1,
        WRAPPED: 2,
        PENDING: 3
      };
      exports.FindState = FindState;
      const FIND_TIMEOUT = 250;
      const MATCH_SCROLL_OFFSET_TOP = -50;
      const MATCH_SCROLL_OFFSET_LEFT = -400;
      const CHARACTERS_TO_NORMALIZE = {
        "\u2010": "-",
        "\u2018": "'",
        "\u2019": "'",
        "\u201A": "'",
        "\u201B": "'",
        "\u201C": '"',
        "\u201D": '"',
        "\u201E": '"',
        "\u201F": '"',
        "\xBC": "1/4",
        "\xBD": "1/2",
        "\xBE": "3/4"
      };
      const DIACRITICS_EXCEPTION = /* @__PURE__ */ new Set([12441, 12442, 2381, 2509, 2637, 2765, 2893, 3021, 3149, 3277, 3387, 3388, 3405, 3530, 3642, 3770, 3972, 4153, 4154, 5908, 5940, 6098, 6752, 6980, 7082, 7083, 7154, 7155, 11647, 43014, 43052, 43204, 43347, 43456, 43766, 44013, 3158, 3953, 3954, 3962, 3963, 3964, 3965, 3968, 3956]);
      const DIACRITICS_EXCEPTION_STR = [...DIACRITICS_EXCEPTION.values()].map((x) => String.fromCharCode(x)).join("");
      const DIACRITICS_REG_EXP = new RegExp("\\p{M}+", "gu");
      const SPECIAL_CHARS_REG_EXP = new RegExp("([.*+?^${}()|[\\]\\\\])|(\\p{P})|(\\s+)|(\\p{M})|(\\p{L})", "gu");
      const NOT_DIACRITIC_FROM_END_REG_EXP = new RegExp("([^\\p{M}])\\p{M}*$", "u");
      const NOT_DIACRITIC_FROM_START_REG_EXP = new RegExp("^\\p{M}*([^\\p{M}])", "u");
      const SYLLABLES_REG_EXP = /[\uAC00-\uD7AF\uFA6C\uFACF-\uFAD1\uFAD5-\uFAD7]+/g;
      const SYLLABLES_LENGTHS = /* @__PURE__ */ new Map();
      const FIRST_CHAR_SYLLABLES_REG_EXP = "[\\u1100-\\u1112\\ud7a4-\\ud7af\\ud84a\\ud84c\\ud850\\ud854\\ud857\\ud85f]";
      let noSyllablesRegExp = null;
      let withSyllablesRegExp = null;
      function normalize(text) {
        const syllablePositions = [];
        let m;
        while ((m = SYLLABLES_REG_EXP.exec(text)) !== null) {
          let {
            index
          } = m;
          for (const char of m[0]) {
            let len = SYLLABLES_LENGTHS.get(char);
            if (!len) {
              len = char.normalize("NFD").length;
              SYLLABLES_LENGTHS.set(char, len);
            }
            syllablePositions.push([len, index++]);
          }
        }
        let normalizationRegex;
        if (syllablePositions.length === 0 && noSyllablesRegExp) {
          normalizationRegex = noSyllablesRegExp;
        } else if (syllablePositions.length > 0 && withSyllablesRegExp) {
          normalizationRegex = withSyllablesRegExp;
        } else {
          const replace = Object.keys(CHARACTERS_TO_NORMALIZE).join("");
          const regexp = `([${replace}])|(\\p{M}+(?:-\\n)?)|(\\S-\\n)|(\\n)`;
          if (syllablePositions.length === 0) {
            normalizationRegex = noSyllablesRegExp = new RegExp(regexp + "|(\\u0000)", "gum");
          } else {
            normalizationRegex = withSyllablesRegExp = new RegExp(regexp + `|(${FIRST_CHAR_SYLLABLES_REG_EXP})`, "gum");
          }
        }
        const rawDiacriticsPositions = [];
        while ((m = DIACRITICS_REG_EXP.exec(text)) !== null) {
          rawDiacriticsPositions.push([m[0].length, m.index]);
        }
        let normalized = text.normalize("NFD");
        const positions = [[0, 0]];
        let rawDiacriticsIndex = 0;
        let syllableIndex = 0;
        let shift = 0;
        let shiftOrigin = 0;
        let eol = 0;
        let hasDiacritics = false;
        normalized = normalized.replace(normalizationRegex, (match, p1, p2, p3, p4, p5, i) => {
          var _a, _b;
          i -= shiftOrigin;
          if (p1) {
            const replacement = CHARACTERS_TO_NORMALIZE[match];
            const jj = replacement.length;
            for (let j = 1; j < jj; j++) {
              positions.push([i - shift + j, shift - j]);
            }
            shift -= jj - 1;
            return replacement;
          }
          if (p2) {
            const hasTrailingDashEOL = p2.endsWith("\n");
            const len = hasTrailingDashEOL ? p2.length - 2 : p2.length;
            hasDiacritics = true;
            let jj = len;
            if (i + eol === ((_a = rawDiacriticsPositions[rawDiacriticsIndex]) == null ? void 0 : _a[1])) {
              jj -= rawDiacriticsPositions[rawDiacriticsIndex][0];
              ++rawDiacriticsIndex;
            }
            for (let j = 1; j <= jj; j++) {
              positions.push([i - 1 - shift + j, shift - j]);
            }
            shift -= jj;
            shiftOrigin += jj;
            if (hasTrailingDashEOL) {
              i += len - 1;
              positions.push([i - shift + 1, 1 + shift]);
              shift += 1;
              shiftOrigin += 1;
              eol += 1;
              return p2.slice(0, len);
            }
            return p2;
          }
          if (p3) {
            positions.push([i - shift + 1, 1 + shift]);
            shift += 1;
            shiftOrigin += 1;
            eol += 1;
            return p3.charAt(0);
          }
          if (p4) {
            positions.push([i - shift + 1, shift - 1]);
            shift -= 1;
            shiftOrigin += 1;
            eol += 1;
            return " ";
          }
          if (i + eol === ((_b = syllablePositions[syllableIndex]) == null ? void 0 : _b[1])) {
            const newCharLen = syllablePositions[syllableIndex][0] - 1;
            ++syllableIndex;
            for (let j = 1; j <= newCharLen; j++) {
              positions.push([i - (shift - j), shift - j]);
            }
            shift -= newCharLen;
            shiftOrigin += newCharLen;
          }
          return p5;
        });
        positions.push([normalized.length, shift]);
        return [normalized, positions, hasDiacritics];
      }
      function getOriginalIndex(diffs, pos, len) {
        if (!diffs) {
          return [pos, len];
        }
        const start = pos;
        const end = pos + len;
        let i = (0, _ui_utils.binarySearchFirstItem)(diffs, (x) => x[0] >= start);
        if (diffs[i][0] > start) {
          --i;
        }
        let j = (0, _ui_utils.binarySearchFirstItem)(diffs, (x) => x[0] >= end, i);
        if (diffs[j][0] > end) {
          --j;
        }
        return [start + diffs[i][1], len + diffs[j][1] - diffs[i][1]];
      }
      class PDFFindController {
        constructor({
          linkService,
          eventBus
        }) {
          __privateAdd(this, _PDFFindController_instances);
          this._linkService = linkService;
          this._eventBus = eventBus;
          __privateMethod(this, _PDFFindController_instances, reset_fn).call(this);
          eventBus._on("find", __privateMethod(this, _PDFFindController_instances, onFind_fn).bind(this));
          eventBus._on("findbarclose", __privateMethod(this, _PDFFindController_instances, onFindBarClose_fn).bind(this));
        }
        get highlightMatches() {
          return this._highlightMatches;
        }
        get pageMatches() {
          return this._pageMatches;
        }
        get pageMatchesLength() {
          return this._pageMatchesLength;
        }
        get selected() {
          return this._selected;
        }
        get state() {
          return this._state;
        }
        setDocument(pdfDocument) {
          if (this._pdfDocument) {
            __privateMethod(this, _PDFFindController_instances, reset_fn).call(this);
          }
          if (!pdfDocument) {
            return;
          }
          this._pdfDocument = pdfDocument;
          this._firstPageCapability.resolve();
        }
        scrollMatchIntoView({
          element = null,
          selectedLeft = 0,
          pageIndex = -1,
          matchIndex = -1
        }) {
          if (!this._scrollMatches || !element) {
            return;
          } else if (matchIndex === -1 || matchIndex !== this._selected.matchIdx) {
            return;
          } else if (pageIndex === -1 || pageIndex !== this._selected.pageIdx) {
            return;
          }
          this._scrollMatches = false;
          const spot = {
            top: MATCH_SCROLL_OFFSET_TOP,
            left: selectedLeft + MATCH_SCROLL_OFFSET_LEFT
          };
          (0, _ui_utils.scrollIntoView)(element, spot, true);
        }
      }
      _PDFFindController_instances = new WeakSet();
      onFind_fn = function(state) {
        if (!state) {
          return;
        }
        const pdfDocument = this._pdfDocument;
        const {
          type
        } = state;
        if (this._state === null || __privateMethod(this, _PDFFindController_instances, shouldDirtyMatch_fn).call(this, state)) {
          this._dirtyMatch = true;
        }
        this._state = state;
        if (type !== "highlightallchange") {
          __privateMethod(this, _PDFFindController_instances, updateUIState_fn).call(this, FindState.PENDING);
        }
        this._firstPageCapability.promise.then(() => {
          if (!this._pdfDocument || pdfDocument && this._pdfDocument !== pdfDocument) {
            return;
          }
          __privateMethod(this, _PDFFindController_instances, extractText_fn).call(this);
          const findbarClosed = !this._highlightMatches;
          const pendingTimeout = !!this._findTimeout;
          if (this._findTimeout) {
            clearTimeout(this._findTimeout);
            this._findTimeout = null;
          }
          if (!type) {
            this._findTimeout = setTimeout(() => {
              __privateMethod(this, _PDFFindController_instances, nextMatch_fn).call(this);
              this._findTimeout = null;
            }, FIND_TIMEOUT);
          } else if (this._dirtyMatch) {
            __privateMethod(this, _PDFFindController_instances, nextMatch_fn).call(this);
          } else if (type === "again") {
            __privateMethod(this, _PDFFindController_instances, nextMatch_fn).call(this);
            if (findbarClosed && this._state.highlightAll) {
              __privateMethod(this, _PDFFindController_instances, updateAllPages_fn).call(this);
            }
          } else if (type === "highlightallchange") {
            if (pendingTimeout) {
              __privateMethod(this, _PDFFindController_instances, nextMatch_fn).call(this);
            } else {
              this._highlightMatches = true;
            }
            __privateMethod(this, _PDFFindController_instances, updateAllPages_fn).call(this);
          } else {
            __privateMethod(this, _PDFFindController_instances, nextMatch_fn).call(this);
          }
        });
      };
      reset_fn = function() {
        this._highlightMatches = false;
        this._scrollMatches = false;
        this._pdfDocument = null;
        this._pageMatches = [];
        this._pageMatchesLength = [];
        this._state = null;
        this._selected = {
          pageIdx: -1,
          matchIdx: -1
        };
        this._offset = {
          pageIdx: null,
          matchIdx: null,
          wrapped: false
        };
        this._extractTextPromises = [];
        this._pageContents = [];
        this._pageDiffs = [];
        this._hasDiacritics = [];
        this._matchesCountTotal = 0;
        this._pagesToSearch = null;
        this._pendingFindMatches = /* @__PURE__ */ new Set();
        this._resumePageIdx = null;
        this._dirtyMatch = false;
        clearTimeout(this._findTimeout);
        this._findTimeout = null;
        this._firstPageCapability = (0, _pdfjsLib.createPromiseCapability)();
      };
      query_get = function() {
        if (this._state.query !== this._rawQuery) {
          this._rawQuery = this._state.query;
          [this._normalizedQuery] = normalize(this._state.query);
        }
        return this._normalizedQuery;
      };
      shouldDirtyMatch_fn = function(state) {
        if (state.query !== this._state.query) {
          return true;
        }
        switch (state.type) {
          case "again":
            const pageNumber = this._selected.pageIdx + 1;
            const linkService = this._linkService;
            if (pageNumber >= 1 && pageNumber <= linkService.pagesCount && pageNumber !== linkService.page && !linkService.isPageVisible(pageNumber)) {
              return true;
            }
            return false;
          case "highlightallchange":
            return false;
        }
        return true;
      };
      isEntireWord_fn = function(content, startIdx, length) {
        let match = content.slice(0, startIdx).match(NOT_DIACRITIC_FROM_END_REG_EXP);
        if (match) {
          const first = content.charCodeAt(startIdx);
          const limit = match[1].charCodeAt(0);
          if ((0, _pdf_find_utils.getCharacterType)(first) === (0, _pdf_find_utils.getCharacterType)(limit)) {
            return false;
          }
        }
        match = content.slice(startIdx + length).match(NOT_DIACRITIC_FROM_START_REG_EXP);
        if (match) {
          const last = content.charCodeAt(startIdx + length - 1);
          const limit = match[1].charCodeAt(0);
          if ((0, _pdf_find_utils.getCharacterType)(last) === (0, _pdf_find_utils.getCharacterType)(limit)) {
            return false;
          }
        }
        return true;
      };
      calculateRegExpMatch_fn = function(query, entireWord, pageIndex, pageContent) {
        const matches = [], matchesLength = [];
        const diffs = this._pageDiffs[pageIndex];
        let match;
        while ((match = query.exec(pageContent)) !== null) {
          if (entireWord && !__privateMethod(this, _PDFFindController_instances, isEntireWord_fn).call(this, pageContent, match.index, match[0].length)) {
            continue;
          }
          const [matchPos, matchLen] = getOriginalIndex(diffs, match.index, match[0].length);
          if (matchLen) {
            matches.push(matchPos);
            matchesLength.push(matchLen);
          }
        }
        this._pageMatches[pageIndex] = matches;
        this._pageMatchesLength[pageIndex] = matchesLength;
      };
      convertToRegExpString_fn = function(query, hasDiacritics) {
        const {
          matchDiacritics
        } = this._state;
        let isUnicode = false;
        query = query.replace(SPECIAL_CHARS_REG_EXP, (match, p1, p2, p3, p4, p5) => {
          if (p1) {
            return `[ ]*\\${p1}[ ]*`;
          }
          if (p2) {
            return `[ ]*${p2}[ ]*`;
          }
          if (p3) {
            return "[ ]+";
          }
          if (matchDiacritics) {
            return p4 || p5;
          }
          if (p4) {
            return DIACRITICS_EXCEPTION.has(p4.charCodeAt(0)) ? p4 : "";
          }
          if (hasDiacritics) {
            isUnicode = true;
            return `${p5}\\p{M}*`;
          }
          return p5;
        });
        const trailingSpaces = "[ ]*";
        if (query.endsWith(trailingSpaces)) {
          query = query.slice(0, query.length - trailingSpaces.length);
        }
        if (matchDiacritics) {
          if (hasDiacritics) {
            isUnicode = true;
            query = `${query}(?=[${DIACRITICS_EXCEPTION_STR}]|[^\\p{M}]|$)`;
          }
        }
        return [isUnicode, query];
      };
      calculateMatch_fn = function(pageIndex) {
        let query = __privateGet(this, _PDFFindController_instances, query_get);
        if (query.length === 0) {
          return;
        }
        const {
          caseSensitive,
          entireWord,
          phraseSearch
        } = this._state;
        const pageContent = this._pageContents[pageIndex];
        const hasDiacritics = this._hasDiacritics[pageIndex];
        let isUnicode = false;
        if (phraseSearch) {
          [isUnicode, query] = __privateMethod(this, _PDFFindController_instances, convertToRegExpString_fn).call(this, query, hasDiacritics);
        } else {
          const match = query.match(/\S+/g);
          if (match) {
            query = match.sort().reverse().map((q) => {
              const [isUnicodePart, queryPart] = __privateMethod(this, _PDFFindController_instances, convertToRegExpString_fn).call(this, q, hasDiacritics);
              isUnicode || (isUnicode = isUnicodePart);
              return `(${queryPart})`;
            }).join("|");
          }
        }
        const flags = `g${isUnicode ? "u" : ""}${caseSensitive ? "" : "i"}`;
        query = new RegExp(query, flags);
        __privateMethod(this, _PDFFindController_instances, calculateRegExpMatch_fn).call(this, query, entireWord, pageIndex, pageContent);
        if (this._state.highlightAll) {
          __privateMethod(this, _PDFFindController_instances, updatePage_fn).call(this, pageIndex);
        }
        if (this._resumePageIdx === pageIndex) {
          this._resumePageIdx = null;
          __privateMethod(this, _PDFFindController_instances, nextPageMatch_fn).call(this);
        }
        const pageMatchesCount = this._pageMatches[pageIndex].length;
        if (pageMatchesCount > 0) {
          this._matchesCountTotal += pageMatchesCount;
          __privateMethod(this, _PDFFindController_instances, updateUIResultsCount_fn).call(this);
        }
      };
      extractText_fn = function() {
        if (this._extractTextPromises.length > 0) {
          return;
        }
        let promise = Promise.resolve();
        for (let i = 0, ii = this._linkService.pagesCount; i < ii; i++) {
          const extractTextCapability = (0, _pdfjsLib.createPromiseCapability)();
          this._extractTextPromises[i] = extractTextCapability.promise;
          promise = promise.then(() => {
            return this._pdfDocument.getPage(i + 1).then((pdfPage) => {
              return pdfPage.getTextContent();
            }).then((textContent) => {
              const strBuf = [];
              for (const textItem of textContent.items) {
                strBuf.push(textItem.str);
                if (textItem.hasEOL) {
                  strBuf.push("\n");
                }
              }
              [this._pageContents[i], this._pageDiffs[i], this._hasDiacritics[i]] = normalize(strBuf.join(""));
              extractTextCapability.resolve();
            }, (reason) => {
              console.error(`Unable to get text content for page ${i + 1}`, reason);
              this._pageContents[i] = "";
              this._pageDiffs[i] = null;
              this._hasDiacritics[i] = false;
              extractTextCapability.resolve();
            });
          });
        }
      };
      updatePage_fn = function(index) {
        if (this._scrollMatches && this._selected.pageIdx === index) {
          this._linkService.page = index + 1;
        }
        this._eventBus.dispatch("updatetextlayermatches", {
          source: this,
          pageIndex: index
        });
      };
      updateAllPages_fn = function() {
        this._eventBus.dispatch("updatetextlayermatches", {
          source: this,
          pageIndex: -1
        });
      };
      nextMatch_fn = function() {
        const previous = this._state.findPrevious;
        const currentPageIndex = this._linkService.page - 1;
        const numPages = this._linkService.pagesCount;
        this._highlightMatches = true;
        if (this._dirtyMatch) {
          this._dirtyMatch = false;
          this._selected.pageIdx = this._selected.matchIdx = -1;
          this._offset.pageIdx = currentPageIndex;
          this._offset.matchIdx = null;
          this._offset.wrapped = false;
          this._resumePageIdx = null;
          this._pageMatches.length = 0;
          this._pageMatchesLength.length = 0;
          this._matchesCountTotal = 0;
          __privateMethod(this, _PDFFindController_instances, updateAllPages_fn).call(this);
          for (let i = 0; i < numPages; i++) {
            if (this._pendingFindMatches.has(i)) {
              continue;
            }
            this._pendingFindMatches.add(i);
            this._extractTextPromises[i].then(() => {
              this._pendingFindMatches.delete(i);
              __privateMethod(this, _PDFFindController_instances, calculateMatch_fn).call(this, i);
            });
          }
        }
        if (__privateGet(this, _PDFFindController_instances, query_get) === "") {
          __privateMethod(this, _PDFFindController_instances, updateUIState_fn).call(this, FindState.FOUND);
          return;
        }
        if (this._resumePageIdx) {
          return;
        }
        const offset = this._offset;
        this._pagesToSearch = numPages;
        if (offset.matchIdx !== null) {
          const numPageMatches = this._pageMatches[offset.pageIdx].length;
          if (!previous && offset.matchIdx + 1 < numPageMatches || previous && offset.matchIdx > 0) {
            offset.matchIdx = previous ? offset.matchIdx - 1 : offset.matchIdx + 1;
            __privateMethod(this, _PDFFindController_instances, updateMatch_fn).call(this, true);
            return;
          }
          __privateMethod(this, _PDFFindController_instances, advanceOffsetPage_fn).call(this, previous);
        }
        __privateMethod(this, _PDFFindController_instances, nextPageMatch_fn).call(this);
      };
      matchesReady_fn = function(matches) {
        const offset = this._offset;
        const numMatches = matches.length;
        const previous = this._state.findPrevious;
        if (numMatches) {
          offset.matchIdx = previous ? numMatches - 1 : 0;
          __privateMethod(this, _PDFFindController_instances, updateMatch_fn).call(this, true);
          return true;
        }
        __privateMethod(this, _PDFFindController_instances, advanceOffsetPage_fn).call(this, previous);
        if (offset.wrapped) {
          offset.matchIdx = null;
          if (this._pagesToSearch < 0) {
            __privateMethod(this, _PDFFindController_instances, updateMatch_fn).call(this, false);
            return true;
          }
        }
        return false;
      };
      nextPageMatch_fn = function() {
        if (this._resumePageIdx !== null) {
          console.error("There can only be one pending page.");
        }
        let matches = null;
        do {
          const pageIdx = this._offset.pageIdx;
          matches = this._pageMatches[pageIdx];
          if (!matches) {
            this._resumePageIdx = pageIdx;
            break;
          }
        } while (!__privateMethod(this, _PDFFindController_instances, matchesReady_fn).call(this, matches));
      };
      advanceOffsetPage_fn = function(previous) {
        const offset = this._offset;
        const numPages = this._linkService.pagesCount;
        offset.pageIdx = previous ? offset.pageIdx - 1 : offset.pageIdx + 1;
        offset.matchIdx = null;
        this._pagesToSearch--;
        if (offset.pageIdx >= numPages || offset.pageIdx < 0) {
          offset.pageIdx = previous ? numPages - 1 : 0;
          offset.wrapped = true;
        }
      };
      updateMatch_fn = function(found = false) {
        let state = FindState.NOT_FOUND;
        const wrapped = this._offset.wrapped;
        this._offset.wrapped = false;
        if (found) {
          const previousPage = this._selected.pageIdx;
          this._selected.pageIdx = this._offset.pageIdx;
          this._selected.matchIdx = this._offset.matchIdx;
          state = wrapped ? FindState.WRAPPED : FindState.FOUND;
          if (previousPage !== -1 && previousPage !== this._selected.pageIdx) {
            __privateMethod(this, _PDFFindController_instances, updatePage_fn).call(this, previousPage);
          }
        }
        __privateMethod(this, _PDFFindController_instances, updateUIState_fn).call(this, state, this._state.findPrevious);
        if (this._selected.pageIdx !== -1) {
          this._scrollMatches = true;
          __privateMethod(this, _PDFFindController_instances, updatePage_fn).call(this, this._selected.pageIdx);
        }
      };
      onFindBarClose_fn = function(evt) {
        const pdfDocument = this._pdfDocument;
        this._firstPageCapability.promise.then(() => {
          if (!this._pdfDocument || pdfDocument && this._pdfDocument !== pdfDocument) {
            return;
          }
          if (this._findTimeout) {
            clearTimeout(this._findTimeout);
            this._findTimeout = null;
          }
          if (this._resumePageIdx) {
            this._resumePageIdx = null;
            this._dirtyMatch = true;
          }
          __privateMethod(this, _PDFFindController_instances, updateUIState_fn).call(this, FindState.FOUND);
          this._highlightMatches = false;
          __privateMethod(this, _PDFFindController_instances, updateAllPages_fn).call(this);
        });
      };
      requestMatchesCount_fn = function() {
        var _a;
        const {
          pageIdx,
          matchIdx
        } = this._selected;
        let current = 0, total = this._matchesCountTotal;
        if (matchIdx !== -1) {
          for (let i = 0; i < pageIdx; i++) {
            current += ((_a = this._pageMatches[i]) == null ? void 0 : _a.length) || 0;
          }
          current += matchIdx + 1;
        }
        if (current < 1 || current > total) {
          current = total = 0;
        }
        return {
          current,
          total
        };
      };
      updateUIResultsCount_fn = function() {
        this._eventBus.dispatch("updatefindmatchescount", {
          source: this,
          matchesCount: __privateMethod(this, _PDFFindController_instances, requestMatchesCount_fn).call(this)
        });
      };
      updateUIState_fn = function(state, previous = false) {
        var _a;
        this._eventBus.dispatch("updatefindcontrolstate", {
          source: this,
          state,
          previous,
          matchesCount: __privateMethod(this, _PDFFindController_instances, requestMatchesCount_fn).call(this),
          rawQuery: ((_a = this._state) == null ? void 0 : _a.query) ?? null
        });
      };
      exports.PDFFindController = PDFFindController;
    }),
    /* 17 */
    /***/
    ((__unused_webpack_module, exports) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.CharacterType = void 0;
      exports.getCharacterType = getCharacterType;
      const CharacterType = {
        SPACE: 0,
        ALPHA_LETTER: 1,
        PUNCT: 2,
        HAN_LETTER: 3,
        KATAKANA_LETTER: 4,
        HIRAGANA_LETTER: 5,
        HALFWIDTH_KATAKANA_LETTER: 6,
        THAI_LETTER: 7
      };
      exports.CharacterType = CharacterType;
      function isAlphabeticalScript(charCode) {
        return charCode < 11904;
      }
      function isAscii(charCode) {
        return (charCode & 65408) === 0;
      }
      function isAsciiAlpha(charCode) {
        return charCode >= 97 && charCode <= 122 || charCode >= 65 && charCode <= 90;
      }
      function isAsciiDigit(charCode) {
        return charCode >= 48 && charCode <= 57;
      }
      function isAsciiSpace(charCode) {
        return charCode === 32 || charCode === 9 || charCode === 13 || charCode === 10;
      }
      function isHan(charCode) {
        return charCode >= 13312 && charCode <= 40959 || charCode >= 63744 && charCode <= 64255;
      }
      function isKatakana(charCode) {
        return charCode >= 12448 && charCode <= 12543;
      }
      function isHiragana(charCode) {
        return charCode >= 12352 && charCode <= 12447;
      }
      function isHalfwidthKatakana(charCode) {
        return charCode >= 65376 && charCode <= 65439;
      }
      function isThai(charCode) {
        return (charCode & 65408) === 3584;
      }
      function getCharacterType(charCode) {
        if (isAlphabeticalScript(charCode)) {
          if (isAscii(charCode)) {
            if (isAsciiSpace(charCode)) {
              return CharacterType.SPACE;
            } else if (isAsciiAlpha(charCode) || isAsciiDigit(charCode) || charCode === 95) {
              return CharacterType.ALPHA_LETTER;
            }
            return CharacterType.PUNCT;
          } else if (isThai(charCode)) {
            return CharacterType.THAI_LETTER;
          } else if (charCode === 160) {
            return CharacterType.SPACE;
          }
          return CharacterType.ALPHA_LETTER;
        }
        if (isHan(charCode)) {
          return CharacterType.HAN_LETTER;
        } else if (isKatakana(charCode)) {
          return CharacterType.KATAKANA_LETTER;
        } else if (isHiragana(charCode)) {
          return CharacterType.HIRAGANA_LETTER;
        } else if (isHalfwidthKatakana(charCode)) {
          return CharacterType.HALFWIDTH_KATAKANA_LETTER;
        }
        return CharacterType.ALPHA_LETTER;
      }
    }),
    /* 18 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFHistory = void 0;
      exports.isDestArraysEqual = isDestArraysEqual;
      exports.isDestHashesEqual = isDestHashesEqual;
      var _ui_utils = __webpack_require__2(1);
      var _event_utils = __webpack_require__2(6);
      const HASH_CHANGE_TIMEOUT = 1e3;
      const POSITION_UPDATED_THRESHOLD = 50;
      const UPDATE_VIEWAREA_TIMEOUT = 1e3;
      function getCurrentHash() {
        return document.location.hash;
      }
      class PDFHistory {
        constructor({
          linkService,
          eventBus
        }) {
          this.linkService = linkService;
          this.eventBus = eventBus;
          this._initialized = false;
          this._fingerprint = "";
          this.reset();
          this._boundEvents = null;
          this.eventBus._on("pagesinit", () => {
            this._isPagesLoaded = false;
            this.eventBus._on("pagesloaded", (evt) => {
              this._isPagesLoaded = !!evt.pagesCount;
            }, {
              once: true
            });
          });
        }
        initialize({
          fingerprint,
          resetHistory = false,
          updateUrl = false
        }) {
          if (!fingerprint || typeof fingerprint !== "string") {
            console.error('PDFHistory.initialize: The "fingerprint" must be a non-empty string.');
            return;
          }
          if (this._initialized) {
            this.reset();
          }
          const reInitialized = this._fingerprint !== "" && this._fingerprint !== fingerprint;
          this._fingerprint = fingerprint;
          this._updateUrl = updateUrl === true;
          this._initialized = true;
          this._bindEvents();
          const state = window.history.state;
          this._popStateInProgress = false;
          this._blockHashChange = 0;
          this._currentHash = getCurrentHash();
          this._numPositionUpdates = 0;
          this._uid = this._maxUid = 0;
          this._destination = null;
          this._position = null;
          if (!this._isValidState(state, true) || resetHistory) {
            const {
              hash,
              page,
              rotation
            } = this._parseCurrentHash(true);
            if (!hash || reInitialized || resetHistory) {
              this._pushOrReplaceState(null, true);
              return;
            }
            this._pushOrReplaceState({
              hash,
              page,
              rotation
            }, true);
            return;
          }
          const destination = state.destination;
          this._updateInternalState(destination, state.uid, true);
          if (destination.rotation !== void 0) {
            this._initialRotation = destination.rotation;
          }
          if (destination.dest) {
            this._initialBookmark = JSON.stringify(destination.dest);
            this._destination.page = null;
          } else if (destination.hash) {
            this._initialBookmark = destination.hash;
          } else if (destination.page) {
            this._initialBookmark = `page=${destination.page}`;
          }
        }
        reset() {
          if (this._initialized) {
            this._pageHide();
            this._initialized = false;
            this._unbindEvents();
          }
          if (this._updateViewareaTimeout) {
            clearTimeout(this._updateViewareaTimeout);
            this._updateViewareaTimeout = null;
          }
          this._initialBookmark = null;
          this._initialRotation = null;
        }
        push({
          namedDest = null,
          explicitDest,
          pageNumber
        }) {
          if (!this._initialized) {
            return;
          }
          if (namedDest && typeof namedDest !== "string") {
            console.error(`PDFHistory.push: "${namedDest}" is not a valid namedDest parameter.`);
            return;
          } else if (!Array.isArray(explicitDest)) {
            console.error(`PDFHistory.push: "${explicitDest}" is not a valid explicitDest parameter.`);
            return;
          } else if (!this._isValidPage(pageNumber)) {
            if (pageNumber !== null || this._destination) {
              console.error(`PDFHistory.push: "${pageNumber}" is not a valid pageNumber parameter.`);
              return;
            }
          }
          const hash = namedDest || JSON.stringify(explicitDest);
          if (!hash) {
            return;
          }
          let forceReplace = false;
          if (this._destination && (isDestHashesEqual(this._destination.hash, hash) || isDestArraysEqual(this._destination.dest, explicitDest))) {
            if (this._destination.page) {
              return;
            }
            forceReplace = true;
          }
          if (this._popStateInProgress && !forceReplace) {
            return;
          }
          this._pushOrReplaceState({
            dest: explicitDest,
            hash,
            page: pageNumber,
            rotation: this.linkService.rotation
          }, forceReplace);
          if (!this._popStateInProgress) {
            this._popStateInProgress = true;
            Promise.resolve().then(() => {
              this._popStateInProgress = false;
            });
          }
        }
        pushPage(pageNumber) {
          var _a;
          if (!this._initialized) {
            return;
          }
          if (!this._isValidPage(pageNumber)) {
            console.error(`PDFHistory.pushPage: "${pageNumber}" is not a valid page number.`);
            return;
          }
          if (((_a = this._destination) == null ? void 0 : _a.page) === pageNumber) {
            return;
          }
          if (this._popStateInProgress) {
            return;
          }
          this._pushOrReplaceState({
            dest: null,
            hash: `page=${pageNumber}`,
            page: pageNumber,
            rotation: this.linkService.rotation
          });
          if (!this._popStateInProgress) {
            this._popStateInProgress = true;
            Promise.resolve().then(() => {
              this._popStateInProgress = false;
            });
          }
        }
        pushCurrentPosition() {
          if (!this._initialized || this._popStateInProgress) {
            return;
          }
          this._tryPushCurrentPosition();
        }
        back() {
          if (!this._initialized || this._popStateInProgress) {
            return;
          }
          const state = window.history.state;
          if (this._isValidState(state) && state.uid > 0) {
            window.history.back();
          }
        }
        forward() {
          if (!this._initialized || this._popStateInProgress) {
            return;
          }
          const state = window.history.state;
          if (this._isValidState(state) && state.uid < this._maxUid) {
            window.history.forward();
          }
        }
        get popStateInProgress() {
          return this._initialized && (this._popStateInProgress || this._blockHashChange > 0);
        }
        get initialBookmark() {
          return this._initialized ? this._initialBookmark : null;
        }
        get initialRotation() {
          return this._initialized ? this._initialRotation : null;
        }
        _pushOrReplaceState(destination, forceReplace = false) {
          const shouldReplace = forceReplace || !this._destination;
          const newState = {
            fingerprint: this._fingerprint,
            uid: shouldReplace ? this._uid : this._uid + 1,
            destination
          };
          this._updateInternalState(destination, newState.uid);
          let newUrl;
          if (this._updateUrl && (destination == null ? void 0 : destination.hash)) {
            const baseUrl = document.location.href.split("#")[0];
            if (!baseUrl.startsWith("file://")) {
              newUrl = `${baseUrl}#${destination.hash}`;
            }
          }
          if (shouldReplace) {
            window.history.replaceState(newState, "", newUrl);
          } else {
            window.history.pushState(newState, "", newUrl);
          }
        }
        _tryPushCurrentPosition(temporary = false) {
          if (!this._position) {
            return;
          }
          let position = this._position;
          if (temporary) {
            position = Object.assign(/* @__PURE__ */ Object.create(null), this._position);
            position.temporary = true;
          }
          if (!this._destination) {
            this._pushOrReplaceState(position);
            return;
          }
          if (this._destination.temporary) {
            this._pushOrReplaceState(position, true);
            return;
          }
          if (this._destination.hash === position.hash) {
            return;
          }
          if (!this._destination.page && (POSITION_UPDATED_THRESHOLD <= 0 || this._numPositionUpdates <= POSITION_UPDATED_THRESHOLD)) {
            return;
          }
          let forceReplace = false;
          if (this._destination.page >= position.first && this._destination.page <= position.page) {
            if (this._destination.dest !== void 0 || !this._destination.first) {
              return;
            }
            forceReplace = true;
          }
          this._pushOrReplaceState(position, forceReplace);
        }
        _isValidPage(val) {
          return Number.isInteger(val) && val > 0 && val <= this.linkService.pagesCount;
        }
        _isValidState(state, checkReload = false) {
          if (!state) {
            return false;
          }
          if (state.fingerprint !== this._fingerprint) {
            if (checkReload) {
              if (typeof state.fingerprint !== "string" || state.fingerprint.length !== this._fingerprint.length) {
                return false;
              }
              const [perfEntry] = performance.getEntriesByType("navigation");
              if ((perfEntry == null ? void 0 : perfEntry.type) !== "reload") {
                return false;
              }
            } else {
              return false;
            }
          }
          if (!Number.isInteger(state.uid) || state.uid < 0) {
            return false;
          }
          if (state.destination === null || typeof state.destination !== "object") {
            return false;
          }
          return true;
        }
        _updateInternalState(destination, uid, removeTemporary = false) {
          if (this._updateViewareaTimeout) {
            clearTimeout(this._updateViewareaTimeout);
            this._updateViewareaTimeout = null;
          }
          if (removeTemporary && (destination == null ? void 0 : destination.temporary)) {
            delete destination.temporary;
          }
          this._destination = destination;
          this._uid = uid;
          this._maxUid = Math.max(this._maxUid, uid);
          this._numPositionUpdates = 0;
        }
        _parseCurrentHash(checkNameddest = false) {
          const hash = unescape(getCurrentHash()).substring(1);
          const params = (0, _ui_utils.parseQueryString)(hash);
          const nameddest = params.get("nameddest") || "";
          let page = params.get("page") | 0;
          if (!this._isValidPage(page) || checkNameddest && nameddest.length > 0) {
            page = null;
          }
          return {
            hash,
            page,
            rotation: this.linkService.rotation
          };
        }
        _updateViewarea({
          location
        }) {
          if (this._updateViewareaTimeout) {
            clearTimeout(this._updateViewareaTimeout);
            this._updateViewareaTimeout = null;
          }
          this._position = {
            hash: location.pdfOpenParams.substring(1),
            page: this.linkService.page,
            first: location.pageNumber,
            rotation: location.rotation
          };
          if (this._popStateInProgress) {
            return;
          }
          if (POSITION_UPDATED_THRESHOLD > 0 && this._isPagesLoaded && this._destination && !this._destination.page) {
            this._numPositionUpdates++;
          }
          if (UPDATE_VIEWAREA_TIMEOUT > 0) {
            this._updateViewareaTimeout = setTimeout(() => {
              if (!this._popStateInProgress) {
                this._tryPushCurrentPosition(true);
              }
              this._updateViewareaTimeout = null;
            }, UPDATE_VIEWAREA_TIMEOUT);
          }
        }
        _popState({
          state
        }) {
          const newHash = getCurrentHash(), hashChanged = this._currentHash !== newHash;
          this._currentHash = newHash;
          if (!state) {
            this._uid++;
            const {
              hash,
              page,
              rotation
            } = this._parseCurrentHash();
            this._pushOrReplaceState({
              hash,
              page,
              rotation
            }, true);
            return;
          }
          if (!this._isValidState(state)) {
            return;
          }
          this._popStateInProgress = true;
          if (hashChanged) {
            this._blockHashChange++;
            (0, _event_utils.waitOnEventOrTimeout)({
              target: window,
              name: "hashchange",
              delay: HASH_CHANGE_TIMEOUT
            }).then(() => {
              this._blockHashChange--;
            });
          }
          const destination = state.destination;
          this._updateInternalState(destination, state.uid, true);
          if ((0, _ui_utils.isValidRotation)(destination.rotation)) {
            this.linkService.rotation = destination.rotation;
          }
          if (destination.dest) {
            this.linkService.goToDestination(destination.dest);
          } else if (destination.hash) {
            this.linkService.setHash(destination.hash);
          } else if (destination.page) {
            this.linkService.page = destination.page;
          }
          Promise.resolve().then(() => {
            this._popStateInProgress = false;
          });
        }
        _pageHide() {
          if (!this._destination || this._destination.temporary) {
            this._tryPushCurrentPosition();
          }
        }
        _bindEvents() {
          if (this._boundEvents) {
            return;
          }
          this._boundEvents = {
            updateViewarea: this._updateViewarea.bind(this),
            popState: this._popState.bind(this),
            pageHide: this._pageHide.bind(this)
          };
          this.eventBus._on("updateviewarea", this._boundEvents.updateViewarea);
          window.addEventListener("popstate", this._boundEvents.popState);
          window.addEventListener("pagehide", this._boundEvents.pageHide);
        }
        _unbindEvents() {
          if (!this._boundEvents) {
            return;
          }
          this.eventBus._off("updateviewarea", this._boundEvents.updateViewarea);
          window.removeEventListener("popstate", this._boundEvents.popState);
          window.removeEventListener("pagehide", this._boundEvents.pageHide);
          this._boundEvents = null;
        }
      }
      exports.PDFHistory = PDFHistory;
      function isDestHashesEqual(destHash, pushHash) {
        if (typeof destHash !== "string" || typeof pushHash !== "string") {
          return false;
        }
        if (destHash === pushHash) {
          return true;
        }
        const nameddest = (0, _ui_utils.parseQueryString)(destHash).get("nameddest");
        if (nameddest === pushHash) {
          return true;
        }
        return false;
      }
      function isDestArraysEqual(firstDest, secondDest) {
        function isEntryEqual(first, second) {
          if (typeof first !== typeof second) {
            return false;
          }
          if (Array.isArray(first) || Array.isArray(second)) {
            return false;
          }
          if (first !== null && typeof first === "object" && second !== null) {
            if (Object.keys(first).length !== Object.keys(second).length) {
              return false;
            }
            for (const key in first) {
              if (!isEntryEqual(first[key], second[key])) {
                return false;
              }
            }
            return true;
          }
          return first === second || Number.isNaN(first) && Number.isNaN(second);
        }
        if (!(Array.isArray(firstDest) && Array.isArray(secondDest))) {
          return false;
        }
        if (firstDest.length !== secondDest.length) {
          return false;
        }
        for (let i = 0, ii = firstDest.length; i < ii; i++) {
          if (!isEntryEqual(firstDest[i], secondDest[i])) {
            return false;
          }
        }
        return true;
      }
    }),
    /* 19 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFLayerViewer = void 0;
      var _base_tree_viewer = __webpack_require__2(13);
      class PDFLayerViewer extends _base_tree_viewer.BaseTreeViewer {
        constructor(options) {
          super(options);
          this.l10n = options.l10n;
          this.eventBus._on("resetlayers", this._resetLayers.bind(this));
          this.eventBus._on("togglelayerstree", this._toggleAllTreeItems.bind(this));
        }
        reset() {
          super.reset();
          this._optionalContentConfig = null;
        }
        _dispatchEvent(layersCount) {
          this.eventBus.dispatch("layersloaded", {
            source: this,
            layersCount
          });
        }
        _bindLink(element, {
          groupId,
          input
        }) {
          const setVisibility = () => {
            this._optionalContentConfig.setVisibility(groupId, input.checked);
            this.eventBus.dispatch("optionalcontentconfig", {
              source: this,
              promise: Promise.resolve(this._optionalContentConfig)
            });
          };
          element.onclick = (evt) => {
            if (evt.target === input) {
              setVisibility();
              return true;
            } else if (evt.target !== element) {
              return true;
            }
            input.checked = !input.checked;
            setVisibility();
            return false;
          };
        }
        async _setNestedName(element, {
          name = null
        }) {
          if (typeof name === "string") {
            element.textContent = this._normalizeTextContent(name);
            return;
          }
          element.textContent = await this.l10n.get("additional_layers");
          element.style.fontStyle = "italic";
        }
        _addToggleButton(div, {
          name = null
        }) {
          super._addToggleButton(div, name === null);
        }
        _toggleAllTreeItems() {
          if (!this._optionalContentConfig) {
            return;
          }
          super._toggleAllTreeItems();
        }
        render({
          optionalContentConfig,
          pdfDocument
        }) {
          if (this._optionalContentConfig) {
            this.reset();
          }
          this._optionalContentConfig = optionalContentConfig || null;
          this._pdfDocument = pdfDocument || null;
          const groups = optionalContentConfig == null ? void 0 : optionalContentConfig.getOrder();
          if (!groups) {
            this._dispatchEvent(0);
            return;
          }
          const fragment = document.createDocumentFragment(), queue = [{
            parent: fragment,
            groups
          }];
          let layersCount = 0, hasAnyNesting = false;
          while (queue.length > 0) {
            const levelData = queue.shift();
            for (const groupId of levelData.groups) {
              const div = document.createElement("div");
              div.className = "treeItem";
              const element = document.createElement("a");
              div.append(element);
              if (typeof groupId === "object") {
                hasAnyNesting = true;
                this._addToggleButton(div, groupId);
                this._setNestedName(element, groupId);
                const itemsDiv = document.createElement("div");
                itemsDiv.className = "treeItems";
                div.append(itemsDiv);
                queue.push({
                  parent: itemsDiv,
                  groups: groupId.order
                });
              } else {
                const group = optionalContentConfig.getGroup(groupId);
                const input = document.createElement("input");
                this._bindLink(element, {
                  groupId,
                  input
                });
                input.type = "checkbox";
                input.checked = group.visible;
                const label = document.createElement("label");
                label.textContent = this._normalizeTextContent(group.name);
                label.append(input);
                element.append(label);
                layersCount++;
              }
              levelData.parent.append(div);
            }
          }
          this._finishRendering(fragment, layersCount, hasAnyNesting);
        }
        async _resetLayers() {
          if (!this._optionalContentConfig) {
            return;
          }
          const optionalContentConfig = await this._pdfDocument.getOptionalContentConfig();
          this.eventBus.dispatch("optionalcontentconfig", {
            source: this,
            promise: Promise.resolve(optionalContentConfig)
          });
          this.render({
            optionalContentConfig,
            pdfDocument: this._pdfDocument
          });
        }
      }
      exports.PDFLayerViewer = PDFLayerViewer;
    }),
    /* 20 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFOutlineViewer = void 0;
      var _base_tree_viewer = __webpack_require__2(13);
      var _pdfjsLib = __webpack_require__2(5);
      var _ui_utils = __webpack_require__2(1);
      class PDFOutlineViewer extends _base_tree_viewer.BaseTreeViewer {
        constructor(options) {
          super(options);
          this.linkService = options.linkService;
          this.eventBus._on("toggleoutlinetree", this._toggleAllTreeItems.bind(this));
          this.eventBus._on("currentoutlineitem", this._currentOutlineItem.bind(this));
          this.eventBus._on("pagechanging", (evt) => {
            this._currentPageNumber = evt.pageNumber;
          });
          this.eventBus._on("pagesloaded", (evt) => {
            this._isPagesLoaded = !!evt.pagesCount;
            if (this._currentOutlineItemCapability && !this._currentOutlineItemCapability.settled) {
              this._currentOutlineItemCapability.resolve(this._isPagesLoaded);
            }
          });
          this.eventBus._on("sidebarviewchanged", (evt) => {
            this._sidebarView = evt.view;
          });
        }
        reset() {
          super.reset();
          this._outline = null;
          this._pageNumberToDestHashCapability = null;
          this._currentPageNumber = 1;
          this._isPagesLoaded = null;
          if (this._currentOutlineItemCapability && !this._currentOutlineItemCapability.settled) {
            this._currentOutlineItemCapability.resolve(false);
          }
          this._currentOutlineItemCapability = null;
        }
        _dispatchEvent(outlineCount) {
          var _a;
          this._currentOutlineItemCapability = (0, _pdfjsLib.createPromiseCapability)();
          if (outlineCount === 0 || ((_a = this._pdfDocument) == null ? void 0 : _a.loadingParams.disableAutoFetch)) {
            this._currentOutlineItemCapability.resolve(false);
          } else if (this._isPagesLoaded !== null) {
            this._currentOutlineItemCapability.resolve(this._isPagesLoaded);
          }
          this.eventBus.dispatch("outlineloaded", {
            source: this,
            outlineCount,
            currentOutlineItemPromise: this._currentOutlineItemCapability.promise
          });
        }
        _bindLink(element, {
          url,
          newWindow,
          dest
        }) {
          const {
            linkService
          } = this;
          if (url) {
            linkService.addLinkAttributes(element, url, newWindow);
            return;
          }
          element.href = linkService.getDestinationHash(dest);
          element.onclick = (evt) => {
            this._updateCurrentTreeItem(evt.target.parentNode);
            if (dest) {
              linkService.goToDestination(dest);
            }
            return false;
          };
        }
        _setStyles(element, {
          bold,
          italic
        }) {
          if (bold) {
            element.style.fontWeight = "bold";
          }
          if (italic) {
            element.style.fontStyle = "italic";
          }
        }
        _addToggleButton(div, {
          count,
          items
        }) {
          let hidden = false;
          if (count < 0) {
            let totalCount = items.length;
            if (totalCount > 0) {
              const queue = [...items];
              while (queue.length > 0) {
                const {
                  count: nestedCount,
                  items: nestedItems
                } = queue.shift();
                if (nestedCount > 0 && nestedItems.length > 0) {
                  totalCount += nestedItems.length;
                  queue.push(...nestedItems);
                }
              }
            }
            if (Math.abs(count) === totalCount) {
              hidden = true;
            }
          }
          super._addToggleButton(div, hidden);
        }
        _toggleAllTreeItems() {
          if (!this._outline) {
            return;
          }
          super._toggleAllTreeItems();
        }
        render({
          outline,
          pdfDocument
        }) {
          if (this._outline) {
            this.reset();
          }
          this._outline = outline || null;
          this._pdfDocument = pdfDocument || null;
          if (!outline) {
            this._dispatchEvent(0);
            return;
          }
          const fragment = document.createDocumentFragment();
          const queue = [{
            parent: fragment,
            items: outline
          }];
          let outlineCount = 0, hasAnyNesting = false;
          while (queue.length > 0) {
            const levelData = queue.shift();
            for (const item of levelData.items) {
              const div = document.createElement("div");
              div.className = "treeItem";
              const element = document.createElement("a");
              this._bindLink(element, item);
              this._setStyles(element, item);
              element.textContent = this._normalizeTextContent(item.title);
              div.append(element);
              if (item.items.length > 0) {
                hasAnyNesting = true;
                this._addToggleButton(div, item);
                const itemsDiv = document.createElement("div");
                itemsDiv.className = "treeItems";
                div.append(itemsDiv);
                queue.push({
                  parent: itemsDiv,
                  items: item.items
                });
              }
              levelData.parent.append(div);
              outlineCount++;
            }
          }
          this._finishRendering(fragment, outlineCount, hasAnyNesting);
        }
        async _currentOutlineItem() {
          if (!this._isPagesLoaded) {
            throw new Error("_currentOutlineItem: All pages have not been loaded.");
          }
          if (!this._outline || !this._pdfDocument) {
            return;
          }
          const pageNumberToDestHash = await this._getPageNumberToDestHash(this._pdfDocument);
          if (!pageNumberToDestHash) {
            return;
          }
          this._updateCurrentTreeItem(null);
          if (this._sidebarView !== _ui_utils.SidebarView.OUTLINE) {
            return;
          }
          for (let i = this._currentPageNumber; i > 0; i--) {
            const destHash = pageNumberToDestHash.get(i);
            if (!destHash) {
              continue;
            }
            const linkElement = this.container.querySelector(`a[href="${destHash}"]`);
            if (!linkElement) {
              continue;
            }
            this._scrollToCurrentTreeItem(linkElement.parentNode);
            break;
          }
        }
        async _getPageNumberToDestHash(pdfDocument) {
          if (this._pageNumberToDestHashCapability) {
            return this._pageNumberToDestHashCapability.promise;
          }
          this._pageNumberToDestHashCapability = (0, _pdfjsLib.createPromiseCapability)();
          const pageNumberToDestHash = /* @__PURE__ */ new Map(), pageNumberNesting = /* @__PURE__ */ new Map();
          const queue = [{
            nesting: 0,
            items: this._outline
          }];
          while (queue.length > 0) {
            const levelData = queue.shift(), currentNesting = levelData.nesting;
            for (const {
              dest,
              items
            } of levelData.items) {
              let explicitDest, pageNumber;
              if (typeof dest === "string") {
                explicitDest = await pdfDocument.getDestination(dest);
                if (pdfDocument !== this._pdfDocument) {
                  return null;
                }
              } else {
                explicitDest = dest;
              }
              if (Array.isArray(explicitDest)) {
                const [destRef] = explicitDest;
                if (typeof destRef === "object" && destRef !== null) {
                  pageNumber = this.linkService._cachedPageNumber(destRef);
                  if (!pageNumber) {
                    try {
                      pageNumber = await pdfDocument.getPageIndex(destRef) + 1;
                      if (pdfDocument !== this._pdfDocument) {
                        return null;
                      }
                      this.linkService.cachePageRef(pageNumber, destRef);
                    } catch (ex) {
                    }
                  }
                } else if (Number.isInteger(destRef)) {
                  pageNumber = destRef + 1;
                }
                if (Number.isInteger(pageNumber) && (!pageNumberToDestHash.has(pageNumber) || currentNesting > pageNumberNesting.get(pageNumber))) {
                  const destHash = this.linkService.getDestinationHash(dest);
                  pageNumberToDestHash.set(pageNumber, destHash);
                  pageNumberNesting.set(pageNumber, currentNesting);
                }
              }
              if (items.length > 0) {
                queue.push({
                  nesting: currentNesting + 1,
                  items
                });
              }
            }
          }
          this._pageNumberToDestHashCapability.resolve(pageNumberToDestHash.size > 0 ? pageNumberToDestHash : null);
          return this._pageNumberToDestHashCapability.promise;
        }
      }
      exports.PDFOutlineViewer = PDFOutlineViewer;
    }),
    /* 21 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _state, _args, _PDFPresentationMode_instances, mouseWheel_fn, notifyStateChange_fn, enter_fn, exit_fn, mouseDown_fn, contextMenu_fn, showControls_fn, hideControls_fn, resetMouseScrollState_fn, touchSwipe_fn, addWindowListeners_fn, removeWindowListeners_fn, fullscreenChange_fn, addFullscreenChangeListeners_fn, removeFullscreenChangeListeners_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFPresentationMode = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _pdfjsLib = __webpack_require__2(5);
      const DELAY_BEFORE_HIDING_CONTROLS = 3e3;
      const ACTIVE_SELECTOR = "pdfPresentationMode";
      const CONTROLS_SELECTOR = "pdfPresentationModeControls";
      const MOUSE_SCROLL_COOLDOWN_TIME = 50;
      const PAGE_SWITCH_THRESHOLD = 0.1;
      const SWIPE_MIN_DISTANCE_THRESHOLD = 50;
      const SWIPE_ANGLE_THRESHOLD = Math.PI / 6;
      class PDFPresentationMode {
        constructor({
          container,
          pdfViewer,
          eventBus
        }) {
          __privateAdd(this, _PDFPresentationMode_instances);
          __privateAdd(this, _state, _ui_utils.PresentationModeState.UNKNOWN);
          __privateAdd(this, _args, null);
          this.container = container;
          this.pdfViewer = pdfViewer;
          this.eventBus = eventBus;
          this.contextMenuOpen = false;
          this.mouseScrollTimeStamp = 0;
          this.mouseScrollDelta = 0;
          this.touchSwipeState = null;
        }
        async request() {
          const {
            container,
            pdfViewer
          } = this;
          if (this.active || !pdfViewer.pagesCount || !container.requestFullscreen) {
            return false;
          }
          __privateMethod(this, _PDFPresentationMode_instances, addFullscreenChangeListeners_fn).call(this);
          __privateMethod(this, _PDFPresentationMode_instances, notifyStateChange_fn).call(this, _ui_utils.PresentationModeState.CHANGING);
          const promise = container.requestFullscreen();
          __privateSet(this, _args, {
            pageNumber: pdfViewer.currentPageNumber,
            scaleValue: pdfViewer.currentScaleValue,
            scrollMode: pdfViewer.scrollMode,
            spreadMode: null,
            annotationEditorMode: null
          });
          if (pdfViewer.spreadMode !== _ui_utils.SpreadMode.NONE && !(pdfViewer.pageViewsReady && pdfViewer.hasEqualPageSizes)) {
            console.warn("Ignoring Spread modes when entering PresentationMode, since the document may contain varying page sizes.");
            __privateGet(this, _args).spreadMode = pdfViewer.spreadMode;
          }
          if (pdfViewer.annotationEditorMode !== _pdfjsLib.AnnotationEditorType.DISABLE) {
            __privateGet(this, _args).annotationEditorMode = pdfViewer.annotationEditorMode;
          }
          try {
            await promise;
            pdfViewer.focus();
            return true;
          } catch (reason) {
            __privateMethod(this, _PDFPresentationMode_instances, removeFullscreenChangeListeners_fn).call(this);
            __privateMethod(this, _PDFPresentationMode_instances, notifyStateChange_fn).call(this, _ui_utils.PresentationModeState.NORMAL);
          }
          return false;
        }
        get active() {
          return __privateGet(this, _state) === _ui_utils.PresentationModeState.CHANGING || __privateGet(this, _state) === _ui_utils.PresentationModeState.FULLSCREEN;
        }
      }
      _state = new WeakMap();
      _args = new WeakMap();
      _PDFPresentationMode_instances = new WeakSet();
      mouseWheel_fn = function(evt) {
        if (!this.active) {
          return;
        }
        evt.preventDefault();
        const delta = (0, _ui_utils.normalizeWheelEventDelta)(evt);
        const currentTime = Date.now();
        const storedTime = this.mouseScrollTimeStamp;
        if (currentTime > storedTime && currentTime - storedTime < MOUSE_SCROLL_COOLDOWN_TIME) {
          return;
        }
        if (this.mouseScrollDelta > 0 && delta < 0 || this.mouseScrollDelta < 0 && delta > 0) {
          __privateMethod(this, _PDFPresentationMode_instances, resetMouseScrollState_fn).call(this);
        }
        this.mouseScrollDelta += delta;
        if (Math.abs(this.mouseScrollDelta) >= PAGE_SWITCH_THRESHOLD) {
          const totalDelta = this.mouseScrollDelta;
          __privateMethod(this, _PDFPresentationMode_instances, resetMouseScrollState_fn).call(this);
          const success = totalDelta > 0 ? this.pdfViewer.previousPage() : this.pdfViewer.nextPage();
          if (success) {
            this.mouseScrollTimeStamp = currentTime;
          }
        }
      };
      notifyStateChange_fn = function(state) {
        __privateSet(this, _state, state);
        this.eventBus.dispatch("presentationmodechanged", {
          source: this,
          state
        });
      };
      enter_fn = function() {
        __privateMethod(this, _PDFPresentationMode_instances, notifyStateChange_fn).call(this, _ui_utils.PresentationModeState.FULLSCREEN);
        this.container.classList.add(ACTIVE_SELECTOR);
        setTimeout(() => {
          this.pdfViewer.scrollMode = _ui_utils.ScrollMode.PAGE;
          if (__privateGet(this, _args).spreadMode !== null) {
            this.pdfViewer.spreadMode = _ui_utils.SpreadMode.NONE;
          }
          this.pdfViewer.currentPageNumber = __privateGet(this, _args).pageNumber;
          this.pdfViewer.currentScaleValue = "page-fit";
          if (__privateGet(this, _args).annotationEditorMode !== null) {
            this.pdfViewer.annotationEditorMode = _pdfjsLib.AnnotationEditorType.NONE;
          }
        }, 0);
        __privateMethod(this, _PDFPresentationMode_instances, addWindowListeners_fn).call(this);
        __privateMethod(this, _PDFPresentationMode_instances, showControls_fn).call(this);
        this.contextMenuOpen = false;
        window.getSelection().removeAllRanges();
      };
      exit_fn = function() {
        const pageNumber = this.pdfViewer.currentPageNumber;
        this.container.classList.remove(ACTIVE_SELECTOR);
        setTimeout(() => {
          __privateMethod(this, _PDFPresentationMode_instances, removeFullscreenChangeListeners_fn).call(this);
          __privateMethod(this, _PDFPresentationMode_instances, notifyStateChange_fn).call(this, _ui_utils.PresentationModeState.NORMAL);
          this.pdfViewer.scrollMode = __privateGet(this, _args).scrollMode;
          if (__privateGet(this, _args).spreadMode !== null) {
            this.pdfViewer.spreadMode = __privateGet(this, _args).spreadMode;
          }
          this.pdfViewer.currentScaleValue = __privateGet(this, _args).scaleValue;
          this.pdfViewer.currentPageNumber = pageNumber;
          if (__privateGet(this, _args).annotationEditorMode !== null) {
            this.pdfViewer.annotationEditorMode = __privateGet(this, _args).annotationEditorMode;
          }
          __privateSet(this, _args, null);
        }, 0);
        __privateMethod(this, _PDFPresentationMode_instances, removeWindowListeners_fn).call(this);
        __privateMethod(this, _PDFPresentationMode_instances, hideControls_fn).call(this);
        __privateMethod(this, _PDFPresentationMode_instances, resetMouseScrollState_fn).call(this);
        this.contextMenuOpen = false;
      };
      mouseDown_fn = function(evt) {
        if (this.contextMenuOpen) {
          this.contextMenuOpen = false;
          evt.preventDefault();
          return;
        }
        if (evt.button === 0) {
          const isInternalLink = evt.target.href && evt.target.classList.contains("internalLink");
          if (!isInternalLink) {
            evt.preventDefault();
            if (evt.shiftKey) {
              this.pdfViewer.previousPage();
            } else {
              this.pdfViewer.nextPage();
            }
          }
        }
      };
      contextMenu_fn = function() {
        this.contextMenuOpen = true;
      };
      showControls_fn = function() {
        if (this.controlsTimeout) {
          clearTimeout(this.controlsTimeout);
        } else {
          this.container.classList.add(CONTROLS_SELECTOR);
        }
        this.controlsTimeout = setTimeout(() => {
          this.container.classList.remove(CONTROLS_SELECTOR);
          delete this.controlsTimeout;
        }, DELAY_BEFORE_HIDING_CONTROLS);
      };
      hideControls_fn = function() {
        if (!this.controlsTimeout) {
          return;
        }
        clearTimeout(this.controlsTimeout);
        this.container.classList.remove(CONTROLS_SELECTOR);
        delete this.controlsTimeout;
      };
      resetMouseScrollState_fn = function() {
        this.mouseScrollTimeStamp = 0;
        this.mouseScrollDelta = 0;
      };
      touchSwipe_fn = function(evt) {
        if (!this.active) {
          return;
        }
        if (evt.touches.length > 1) {
          this.touchSwipeState = null;
          return;
        }
        switch (evt.type) {
          case "touchstart":
            this.touchSwipeState = {
              startX: evt.touches[0].pageX,
              startY: evt.touches[0].pageY,
              endX: evt.touches[0].pageX,
              endY: evt.touches[0].pageY
            };
            break;
          case "touchmove":
            if (this.touchSwipeState === null) {
              return;
            }
            this.touchSwipeState.endX = evt.touches[0].pageX;
            this.touchSwipeState.endY = evt.touches[0].pageY;
            evt.preventDefault();
            break;
          case "touchend":
            if (this.touchSwipeState === null) {
              return;
            }
            let delta = 0;
            const dx = this.touchSwipeState.endX - this.touchSwipeState.startX;
            const dy = this.touchSwipeState.endY - this.touchSwipeState.startY;
            const absAngle = Math.abs(Math.atan2(dy, dx));
            if (Math.abs(dx) > SWIPE_MIN_DISTANCE_THRESHOLD && (absAngle <= SWIPE_ANGLE_THRESHOLD || absAngle >= Math.PI - SWIPE_ANGLE_THRESHOLD)) {
              delta = dx;
            } else if (Math.abs(dy) > SWIPE_MIN_DISTANCE_THRESHOLD && Math.abs(absAngle - Math.PI / 2) <= SWIPE_ANGLE_THRESHOLD) {
              delta = dy;
            }
            if (delta > 0) {
              this.pdfViewer.previousPage();
            } else if (delta < 0) {
              this.pdfViewer.nextPage();
            }
            break;
        }
      };
      addWindowListeners_fn = function() {
        this.showControlsBind = __privateMethod(this, _PDFPresentationMode_instances, showControls_fn).bind(this);
        this.mouseDownBind = __privateMethod(this, _PDFPresentationMode_instances, mouseDown_fn).bind(this);
        this.mouseWheelBind = __privateMethod(this, _PDFPresentationMode_instances, mouseWheel_fn).bind(this);
        this.resetMouseScrollStateBind = __privateMethod(this, _PDFPresentationMode_instances, resetMouseScrollState_fn).bind(this);
        this.contextMenuBind = __privateMethod(this, _PDFPresentationMode_instances, contextMenu_fn).bind(this);
        this.touchSwipeBind = __privateMethod(this, _PDFPresentationMode_instances, touchSwipe_fn).bind(this);
        window.addEventListener("mousemove", this.showControlsBind);
        window.addEventListener("mousedown", this.mouseDownBind);
        window.addEventListener("wheel", this.mouseWheelBind, {
          passive: false
        });
        window.addEventListener("keydown", this.resetMouseScrollStateBind);
        window.addEventListener("contextmenu", this.contextMenuBind);
        window.addEventListener("touchstart", this.touchSwipeBind);
        window.addEventListener("touchmove", this.touchSwipeBind);
        window.addEventListener("touchend", this.touchSwipeBind);
      };
      removeWindowListeners_fn = function() {
        window.removeEventListener("mousemove", this.showControlsBind);
        window.removeEventListener("mousedown", this.mouseDownBind);
        window.removeEventListener("wheel", this.mouseWheelBind, {
          passive: false
        });
        window.removeEventListener("keydown", this.resetMouseScrollStateBind);
        window.removeEventListener("contextmenu", this.contextMenuBind);
        window.removeEventListener("touchstart", this.touchSwipeBind);
        window.removeEventListener("touchmove", this.touchSwipeBind);
        window.removeEventListener("touchend", this.touchSwipeBind);
        delete this.showControlsBind;
        delete this.mouseDownBind;
        delete this.mouseWheelBind;
        delete this.resetMouseScrollStateBind;
        delete this.contextMenuBind;
        delete this.touchSwipeBind;
      };
      fullscreenChange_fn = function() {
        if (document.fullscreenElement) {
          __privateMethod(this, _PDFPresentationMode_instances, enter_fn).call(this);
        } else {
          __privateMethod(this, _PDFPresentationMode_instances, exit_fn).call(this);
        }
      };
      addFullscreenChangeListeners_fn = function() {
        this.fullscreenChangeBind = __privateMethod(this, _PDFPresentationMode_instances, fullscreenChange_fn).bind(this);
        window.addEventListener("fullscreenchange", this.fullscreenChangeBind);
      };
      removeFullscreenChangeListeners_fn = function() {
        window.removeEventListener("fullscreenchange", this.fullscreenChangeBind);
        delete this.fullscreenChangeBind;
      };
      exports.PDFPresentationMode = PDFPresentationMode;
    }),
    /* 22 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFRenderingQueue = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      var _ui_utils = __webpack_require__2(1);
      const CLEANUP_TIMEOUT = 3e4;
      class PDFRenderingQueue {
        constructor() {
          this.pdfViewer = null;
          this.pdfThumbnailViewer = null;
          this.onIdle = null;
          this.highestPriorityPage = null;
          this.idleTimeout = null;
          this.printing = false;
          this.isThumbnailViewEnabled = false;
        }
        setViewer(pdfViewer) {
          this.pdfViewer = pdfViewer;
        }
        setThumbnailViewer(pdfThumbnailViewer) {
          this.pdfThumbnailViewer = pdfThumbnailViewer;
        }
        isHighestPriority(view) {
          return this.highestPriorityPage === view.renderingId;
        }
        hasViewer() {
          return !!this.pdfViewer;
        }
        renderHighestPriority(currentlyVisiblePages) {
          var _a;
          if (this.idleTimeout) {
            clearTimeout(this.idleTimeout);
            this.idleTimeout = null;
          }
          if (this.pdfViewer.forceRendering(currentlyVisiblePages)) {
            return;
          }
          if (this.isThumbnailViewEnabled && ((_a = this.pdfThumbnailViewer) == null ? void 0 : _a.forceRendering())) {
            return;
          }
          if (this.printing) {
            return;
          }
          if (this.onIdle) {
            this.idleTimeout = setTimeout(this.onIdle.bind(this), CLEANUP_TIMEOUT);
          }
        }
        getHighestPriority(visible, views, scrolledDown, preRenderExtra = false) {
          const visibleViews = visible.views, numVisible = visibleViews.length;
          if (numVisible === 0) {
            return null;
          }
          for (let i = 0; i < numVisible; i++) {
            const view = visibleViews[i].view;
            if (!this.isViewFinished(view)) {
              return view;
            }
          }
          const firstId = visible.first.id, lastId = visible.last.id;
          if (lastId - firstId + 1 > numVisible) {
            const visibleIds = visible.ids;
            for (let i = 1, ii = lastId - firstId; i < ii; i++) {
              const holeId = scrolledDown ? firstId + i : lastId - i;
              if (visibleIds.has(holeId)) {
                continue;
              }
              const holeView = views[holeId - 1];
              if (!this.isViewFinished(holeView)) {
                return holeView;
              }
            }
          }
          let preRenderIndex = scrolledDown ? lastId : firstId - 2;
          let preRenderView = views[preRenderIndex];
          if (preRenderView && !this.isViewFinished(preRenderView)) {
            return preRenderView;
          }
          if (preRenderExtra) {
            preRenderIndex += scrolledDown ? 1 : -1;
            preRenderView = views[preRenderIndex];
            if (preRenderView && !this.isViewFinished(preRenderView)) {
              return preRenderView;
            }
          }
          return null;
        }
        isViewFinished(view) {
          return view.renderingState === _ui_utils.RenderingStates.FINISHED;
        }
        renderView(view) {
          switch (view.renderingState) {
            case _ui_utils.RenderingStates.FINISHED:
              return false;
            case _ui_utils.RenderingStates.PAUSED:
              this.highestPriorityPage = view.renderingId;
              view.resume();
              break;
            case _ui_utils.RenderingStates.RUNNING:
              this.highestPriorityPage = view.renderingId;
              break;
            case _ui_utils.RenderingStates.INITIAL:
              this.highestPriorityPage = view.renderingId;
              view.draw().finally(() => {
                this.renderHighestPriority();
              }).catch((reason) => {
                if (reason instanceof _pdfjsLib.RenderingCancelledException) {
                  return;
                }
                console.error(`renderView: "${reason}"`);
              });
              break;
          }
          return true;
        }
      }
      exports.PDFRenderingQueue = PDFRenderingQueue;
    }),
    /* 23 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFScriptingManager = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _pdfjsLib = __webpack_require__2(5);
      class PDFScriptingManager {
        constructor({
          eventBus,
          sandboxBundleSrc = null,
          scriptingFactory = null,
          docPropertiesLookup = null
        }) {
          this._pdfDocument = null;
          this._pdfViewer = null;
          this._closeCapability = null;
          this._destroyCapability = null;
          this._scripting = null;
          this._mouseState = /* @__PURE__ */ Object.create(null);
          this._ready = false;
          this._eventBus = eventBus;
          this._sandboxBundleSrc = sandboxBundleSrc;
          this._scriptingFactory = scriptingFactory;
          this._docPropertiesLookup = docPropertiesLookup;
        }
        setViewer(pdfViewer) {
          this._pdfViewer = pdfViewer;
        }
        async setDocument(pdfDocument) {
          var _a;
          if (this._pdfDocument) {
            await this._destroyScripting();
          }
          this._pdfDocument = pdfDocument;
          if (!pdfDocument) {
            return;
          }
          const [objects, calculationOrder, docActions] = await Promise.all([pdfDocument.getFieldObjects(), pdfDocument.getCalculationOrderIds(), pdfDocument.getJSActions()]);
          if (!objects && !docActions) {
            await this._destroyScripting();
            return;
          }
          if (pdfDocument !== this._pdfDocument) {
            return;
          }
          try {
            this._scripting = this._createScripting();
          } catch (error) {
            console.error(`PDFScriptingManager.setDocument: "${error == null ? void 0 : error.message}".`);
            await this._destroyScripting();
            return;
          }
          this._internalEvents.set("updatefromsandbox", (event) => {
            if ((event == null ? void 0 : event.source) !== window) {
              return;
            }
            this._updateFromSandbox(event.detail);
          });
          this._internalEvents.set("dispatcheventinsandbox", (event) => {
            var _a2;
            (_a2 = this._scripting) == null ? void 0 : _a2.dispatchEventInSandbox(event.detail);
          });
          this._internalEvents.set("pagechanging", ({
            pageNumber,
            previous
          }) => {
            if (pageNumber === previous) {
              return;
            }
            this._dispatchPageClose(previous);
            this._dispatchPageOpen(pageNumber);
          });
          this._internalEvents.set("pagerendered", ({
            pageNumber
          }) => {
            if (!this._pageOpenPending.has(pageNumber)) {
              return;
            }
            if (pageNumber !== this._pdfViewer.currentPageNumber) {
              return;
            }
            this._dispatchPageOpen(pageNumber);
          });
          this._internalEvents.set("pagesdestroy", async (event) => {
            var _a2, _b;
            await this._dispatchPageClose(this._pdfViewer.currentPageNumber);
            await ((_a2 = this._scripting) == null ? void 0 : _a2.dispatchEventInSandbox({
              id: "doc",
              name: "WillClose"
            }));
            (_b = this._closeCapability) == null ? void 0 : _b.resolve();
          });
          this._domEvents.set("mousedown", (event) => {
            this._mouseState.isDown = true;
          });
          this._domEvents.set("mouseup", (event) => {
            this._mouseState.isDown = false;
          });
          for (const [name, listener] of this._internalEvents) {
            this._eventBus._on(name, listener);
          }
          for (const [name, listener] of this._domEvents) {
            window.addEventListener(name, listener, true);
          }
          try {
            const docProperties = await this._getDocProperties();
            if (pdfDocument !== this._pdfDocument) {
              return;
            }
            await this._scripting.createSandbox({
              objects,
              calculationOrder,
              appInfo: {
                platform: navigator.platform,
                language: navigator.language
              },
              docInfo: {
                ...docProperties,
                actions: docActions
              }
            });
            this._eventBus.dispatch("sandboxcreated", {
              source: this
            });
          } catch (error) {
            console.error(`PDFScriptingManager.setDocument: "${error == null ? void 0 : error.message}".`);
            await this._destroyScripting();
            return;
          }
          await ((_a = this._scripting) == null ? void 0 : _a.dispatchEventInSandbox({
            id: "doc",
            name: "Open"
          }));
          await this._dispatchPageOpen(this._pdfViewer.currentPageNumber, true);
          Promise.resolve().then(() => {
            if (pdfDocument === this._pdfDocument) {
              this._ready = true;
            }
          });
        }
        async dispatchWillSave(detail) {
          var _a;
          return (_a = this._scripting) == null ? void 0 : _a.dispatchEventInSandbox({
            id: "doc",
            name: "WillSave"
          });
        }
        async dispatchDidSave(detail) {
          var _a;
          return (_a = this._scripting) == null ? void 0 : _a.dispatchEventInSandbox({
            id: "doc",
            name: "DidSave"
          });
        }
        async dispatchWillPrint(detail) {
          var _a;
          return (_a = this._scripting) == null ? void 0 : _a.dispatchEventInSandbox({
            id: "doc",
            name: "WillPrint"
          });
        }
        async dispatchDidPrint(detail) {
          var _a;
          return (_a = this._scripting) == null ? void 0 : _a.dispatchEventInSandbox({
            id: "doc",
            name: "DidPrint"
          });
        }
        get mouseState() {
          return this._mouseState;
        }
        get destroyPromise() {
          var _a;
          return ((_a = this._destroyCapability) == null ? void 0 : _a.promise) || null;
        }
        get ready() {
          return this._ready;
        }
        get _internalEvents() {
          return (0, _pdfjsLib.shadow)(this, "_internalEvents", /* @__PURE__ */ new Map());
        }
        get _domEvents() {
          return (0, _pdfjsLib.shadow)(this, "_domEvents", /* @__PURE__ */ new Map());
        }
        get _pageOpenPending() {
          return (0, _pdfjsLib.shadow)(this, "_pageOpenPending", /* @__PURE__ */ new Set());
        }
        get _visitedPages() {
          return (0, _pdfjsLib.shadow)(this, "_visitedPages", /* @__PURE__ */ new Map());
        }
        async _updateFromSandbox(detail) {
          var _a;
          const isInPresentationMode = this._pdfViewer.isInPresentationMode || this._pdfViewer.isChangingPresentationMode;
          const {
            id,
            siblings,
            command,
            value
          } = detail;
          if (!id) {
            switch (command) {
              case "clear":
                console.clear();
                break;
              case "error":
                console.error(value);
                break;
              case "layout":
                if (isInPresentationMode) {
                  return;
                }
                const modes = (0, _ui_utils.apiPageLayoutToViewerModes)(value);
                this._pdfViewer.spreadMode = modes.spreadMode;
                break;
              case "page-num":
                this._pdfViewer.currentPageNumber = value + 1;
                break;
              case "print":
                await this._pdfViewer.pagesPromise;
                this._eventBus.dispatch("print", {
                  source: this
                });
                break;
              case "println":
                console.log(value);
                break;
              case "zoom":
                if (isInPresentationMode) {
                  return;
                }
                this._pdfViewer.currentScaleValue = value;
                break;
              case "SaveAs":
                this._eventBus.dispatch("download", {
                  source: this
                });
                break;
              case "FirstPage":
                this._pdfViewer.currentPageNumber = 1;
                break;
              case "LastPage":
                this._pdfViewer.currentPageNumber = this._pdfViewer.pagesCount;
                break;
              case "NextPage":
                this._pdfViewer.nextPage();
                break;
              case "PrevPage":
                this._pdfViewer.previousPage();
                break;
              case "ZoomViewIn":
                if (isInPresentationMode) {
                  return;
                }
                this._pdfViewer.increaseScale();
                break;
              case "ZoomViewOut":
                if (isInPresentationMode) {
                  return;
                }
                this._pdfViewer.decreaseScale();
                break;
            }
            return;
          }
          if (isInPresentationMode) {
            if (detail.focus) {
              return;
            }
          }
          delete detail.id;
          delete detail.siblings;
          const ids = siblings ? [id, ...siblings] : [id];
          for (const elementId of ids) {
            const element = document.querySelector(`[data-element-id="${elementId}"]`);
            if (element) {
              element.dispatchEvent(new CustomEvent("updatefromsandbox", {
                detail
              }));
            } else {
              (_a = this._pdfDocument) == null ? void 0 : _a.annotationStorage.setValue(elementId, detail);
            }
          }
        }
        async _dispatchPageOpen(pageNumber, initialize = false) {
          const pdfDocument = this._pdfDocument, visitedPages = this._visitedPages;
          if (initialize) {
            this._closeCapability = (0, _pdfjsLib.createPromiseCapability)();
          }
          if (!this._closeCapability) {
            return;
          }
          const pageView = this._pdfViewer.getPageView(pageNumber - 1);
          if ((pageView == null ? void 0 : pageView.renderingState) !== _ui_utils.RenderingStates.FINISHED) {
            this._pageOpenPending.add(pageNumber);
            return;
          }
          this._pageOpenPending.delete(pageNumber);
          const actionsPromise = (async () => {
            var _a, _b;
            const actions = await (!visitedPages.has(pageNumber) ? (_a = pageView.pdfPage) == null ? void 0 : _a.getJSActions() : null);
            if (pdfDocument !== this._pdfDocument) {
              return;
            }
            await ((_b = this._scripting) == null ? void 0 : _b.dispatchEventInSandbox({
              id: "page",
              name: "PageOpen",
              pageNumber,
              actions
            }));
          })();
          visitedPages.set(pageNumber, actionsPromise);
        }
        async _dispatchPageClose(pageNumber) {
          var _a;
          const pdfDocument = this._pdfDocument, visitedPages = this._visitedPages;
          if (!this._closeCapability) {
            return;
          }
          if (this._pageOpenPending.has(pageNumber)) {
            return;
          }
          const actionsPromise = visitedPages.get(pageNumber);
          if (!actionsPromise) {
            return;
          }
          visitedPages.set(pageNumber, null);
          await actionsPromise;
          if (pdfDocument !== this._pdfDocument) {
            return;
          }
          await ((_a = this._scripting) == null ? void 0 : _a.dispatchEventInSandbox({
            id: "page",
            name: "PageClose",
            pageNumber
          }));
        }
        async _getDocProperties() {
          if (this._docPropertiesLookup) {
            return this._docPropertiesLookup(this._pdfDocument);
          }
          throw new Error("_getDocProperties: Unable to lookup properties.");
        }
        _createScripting() {
          this._destroyCapability = (0, _pdfjsLib.createPromiseCapability)();
          if (this._scripting) {
            throw new Error("_createScripting: Scripting already exists.");
          }
          if (this._scriptingFactory) {
            return this._scriptingFactory.createScripting({
              sandboxBundleSrc: this._sandboxBundleSrc
            });
          }
          throw new Error("_createScripting: Cannot create scripting.");
        }
        async _destroyScripting() {
          var _a, _b;
          if (!this._scripting) {
            this._pdfDocument = null;
            (_a = this._destroyCapability) == null ? void 0 : _a.resolve();
            return;
          }
          if (this._closeCapability) {
            await Promise.race([this._closeCapability.promise, new Promise((resolve) => {
              setTimeout(resolve, 1e3);
            })]).catch((reason) => {
            });
            this._closeCapability = null;
          }
          this._pdfDocument = null;
          try {
            await this._scripting.destroySandbox();
          } catch (ex) {
          }
          for (const [name, listener] of this._internalEvents) {
            this._eventBus._off(name, listener);
          }
          this._internalEvents.clear();
          for (const [name, listener] of this._domEvents) {
            window.removeEventListener(name, listener, true);
          }
          this._domEvents.clear();
          this._pageOpenPending.clear();
          this._visitedPages.clear();
          this._scripting = null;
          delete this._mouseState.isDown;
          this._ready = false;
          (_b = this._destroyCapability) == null ? void 0 : _b.resolve();
        }
      }
      exports.PDFScriptingManager = PDFScriptingManager;
    }),
    /* 24 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _PDFSidebar_instances, dispatchEvent_fn, forceRendering_fn, updateThumbnailViewer_fn, showUINotification_fn, hideUINotification_fn, addEventListeners_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFSidebar = void 0;
      var _ui_utils = __webpack_require__2(1);
      const UI_NOTIFICATION_CLASS = "pdfSidebarNotification";
      class PDFSidebar {
        constructor({
          elements,
          pdfViewer,
          pdfThumbnailViewer,
          eventBus,
          l10n
        }) {
          __privateAdd(this, _PDFSidebar_instances);
          this.isOpen = false;
          this.active = _ui_utils.SidebarView.THUMBS;
          this.isInitialViewSet = false;
          this.isInitialEventDispatched = false;
          this.onToggled = null;
          this.pdfViewer = pdfViewer;
          this.pdfThumbnailViewer = pdfThumbnailViewer;
          this.outerContainer = elements.outerContainer;
          this.sidebarContainer = elements.sidebarContainer;
          this.toggleButton = elements.toggleButton;
          this.thumbnailButton = elements.thumbnailButton;
          this.outlineButton = elements.outlineButton;
          this.attachmentsButton = elements.attachmentsButton;
          this.layersButton = elements.layersButton;
          this.thumbnailView = elements.thumbnailView;
          this.outlineView = elements.outlineView;
          this.attachmentsView = elements.attachmentsView;
          this.layersView = elements.layersView;
          this._outlineOptionsContainer = elements.outlineOptionsContainer;
          this._currentOutlineItemButton = elements.currentOutlineItemButton;
          this.eventBus = eventBus;
          this.l10n = l10n;
          __privateMethod(this, _PDFSidebar_instances, addEventListeners_fn).call(this);
        }
        reset() {
          this.isInitialViewSet = false;
          this.isInitialEventDispatched = false;
          __privateMethod(this, _PDFSidebar_instances, hideUINotification_fn).call(this, true);
          this.switchView(_ui_utils.SidebarView.THUMBS);
          this.outlineButton.disabled = false;
          this.attachmentsButton.disabled = false;
          this.layersButton.disabled = false;
          this._currentOutlineItemButton.disabled = true;
        }
        get visibleView() {
          return this.isOpen ? this.active : _ui_utils.SidebarView.NONE;
        }
        setInitialView(view = _ui_utils.SidebarView.NONE) {
          if (this.isInitialViewSet) {
            return;
          }
          this.isInitialViewSet = true;
          if (view === _ui_utils.SidebarView.NONE || view === _ui_utils.SidebarView.UNKNOWN) {
            __privateMethod(this, _PDFSidebar_instances, dispatchEvent_fn).call(this);
            return;
          }
          this.switchView(view, true);
          if (!this.isInitialEventDispatched) {
            __privateMethod(this, _PDFSidebar_instances, dispatchEvent_fn).call(this);
          }
        }
        switchView(view, forceOpen = false) {
          const isViewChanged = view !== this.active;
          let shouldForceRendering = false;
          switch (view) {
            case _ui_utils.SidebarView.NONE:
              if (this.isOpen) {
                this.close();
              }
              return;
            case _ui_utils.SidebarView.THUMBS:
              if (this.isOpen && isViewChanged) {
                shouldForceRendering = true;
              }
              break;
            case _ui_utils.SidebarView.OUTLINE:
              if (this.outlineButton.disabled) {
                return;
              }
              break;
            case _ui_utils.SidebarView.ATTACHMENTS:
              if (this.attachmentsButton.disabled) {
                return;
              }
              break;
            case _ui_utils.SidebarView.LAYERS:
              if (this.layersButton.disabled) {
                return;
              }
              break;
            default:
              console.error(`PDFSidebar.switchView: "${view}" is not a valid view.`);
              return;
          }
          this.active = view;
          const isThumbs = view === _ui_utils.SidebarView.THUMBS, isOutline = view === _ui_utils.SidebarView.OUTLINE, isAttachments = view === _ui_utils.SidebarView.ATTACHMENTS, isLayers = view === _ui_utils.SidebarView.LAYERS;
          this.thumbnailButton.classList.toggle("toggled", isThumbs);
          this.outlineButton.classList.toggle("toggled", isOutline);
          this.attachmentsButton.classList.toggle("toggled", isAttachments);
          this.layersButton.classList.toggle("toggled", isLayers);
          this.thumbnailButton.setAttribute("aria-checked", isThumbs);
          this.outlineButton.setAttribute("aria-checked", isOutline);
          this.attachmentsButton.setAttribute("aria-checked", isAttachments);
          this.layersButton.setAttribute("aria-checked", isLayers);
          this.thumbnailView.classList.toggle("hidden", !isThumbs);
          this.outlineView.classList.toggle("hidden", !isOutline);
          this.attachmentsView.classList.toggle("hidden", !isAttachments);
          this.layersView.classList.toggle("hidden", !isLayers);
          this._outlineOptionsContainer.classList.toggle("hidden", !isOutline);
          if (forceOpen && !this.isOpen) {
            this.open();
            return;
          }
          if (shouldForceRendering) {
            __privateMethod(this, _PDFSidebar_instances, updateThumbnailViewer_fn).call(this);
            __privateMethod(this, _PDFSidebar_instances, forceRendering_fn).call(this);
          }
          if (isViewChanged) {
            __privateMethod(this, _PDFSidebar_instances, dispatchEvent_fn).call(this);
          }
        }
        open() {
          if (this.isOpen) {
            return;
          }
          this.isOpen = true;
          this.toggleButton.classList.add("toggled");
          this.toggleButton.setAttribute("aria-expanded", "true");
          this.outerContainer.classList.add("sidebarMoving", "sidebarOpen");
          if (this.active === _ui_utils.SidebarView.THUMBS) {
            __privateMethod(this, _PDFSidebar_instances, updateThumbnailViewer_fn).call(this);
          }
          __privateMethod(this, _PDFSidebar_instances, forceRendering_fn).call(this);
          __privateMethod(this, _PDFSidebar_instances, dispatchEvent_fn).call(this);
          __privateMethod(this, _PDFSidebar_instances, hideUINotification_fn).call(this);
        }
        close() {
          if (!this.isOpen) {
            return;
          }
          this.isOpen = false;
          this.toggleButton.classList.remove("toggled");
          this.toggleButton.setAttribute("aria-expanded", "false");
          this.outerContainer.classList.add("sidebarMoving");
          this.outerContainer.classList.remove("sidebarOpen");
          __privateMethod(this, _PDFSidebar_instances, forceRendering_fn).call(this);
          __privateMethod(this, _PDFSidebar_instances, dispatchEvent_fn).call(this);
        }
        toggle() {
          if (this.isOpen) {
            this.close();
          } else {
            this.open();
          }
        }
      }
      _PDFSidebar_instances = new WeakSet();
      dispatchEvent_fn = function() {
        if (this.isInitialViewSet && !this.isInitialEventDispatched) {
          this.isInitialEventDispatched = true;
        }
        this.eventBus.dispatch("sidebarviewchanged", {
          source: this,
          view: this.visibleView
        });
      };
      forceRendering_fn = function() {
        if (this.onToggled) {
          this.onToggled();
        } else {
          this.pdfViewer.forceRendering();
          this.pdfThumbnailViewer.forceRendering();
        }
      };
      updateThumbnailViewer_fn = function() {
        const {
          pdfViewer,
          pdfThumbnailViewer
        } = this;
        const pagesCount = pdfViewer.pagesCount;
        for (let pageIndex = 0; pageIndex < pagesCount; pageIndex++) {
          const pageView = pdfViewer.getPageView(pageIndex);
          if ((pageView == null ? void 0 : pageView.renderingState) === _ui_utils.RenderingStates.FINISHED) {
            const thumbnailView = pdfThumbnailViewer.getThumbnail(pageIndex);
            thumbnailView.setImage(pageView);
          }
        }
        pdfThumbnailViewer.scrollThumbnailIntoView(pdfViewer.currentPageNumber);
      };
      showUINotification_fn = function() {
        this.l10n.get("toggle_sidebar_notification2.title").then((msg) => {
          this.toggleButton.title = msg;
        });
        if (!this.isOpen) {
          this.toggleButton.classList.add(UI_NOTIFICATION_CLASS);
        }
      };
      hideUINotification_fn = function(reset = false) {
        if (this.isOpen || reset) {
          this.toggleButton.classList.remove(UI_NOTIFICATION_CLASS);
        }
        if (reset) {
          this.l10n.get("toggle_sidebar.title").then((msg) => {
            this.toggleButton.title = msg;
          });
        }
      };
      addEventListeners_fn = function() {
        this.sidebarContainer.addEventListener("transitionend", (evt) => {
          if (evt.target === this.sidebarContainer) {
            this.outerContainer.classList.remove("sidebarMoving");
          }
        });
        this.toggleButton.addEventListener("click", () => {
          this.toggle();
        });
        this.thumbnailButton.addEventListener("click", () => {
          this.switchView(_ui_utils.SidebarView.THUMBS);
        });
        this.outlineButton.addEventListener("click", () => {
          this.switchView(_ui_utils.SidebarView.OUTLINE);
        });
        this.outlineButton.addEventListener("dblclick", () => {
          this.eventBus.dispatch("toggleoutlinetree", {
            source: this
          });
        });
        this.attachmentsButton.addEventListener("click", () => {
          this.switchView(_ui_utils.SidebarView.ATTACHMENTS);
        });
        this.layersButton.addEventListener("click", () => {
          this.switchView(_ui_utils.SidebarView.LAYERS);
        });
        this.layersButton.addEventListener("dblclick", () => {
          this.eventBus.dispatch("resetlayers", {
            source: this
          });
        });
        this._currentOutlineItemButton.addEventListener("click", () => {
          this.eventBus.dispatch("currentoutlineitem", {
            source: this
          });
        });
        const onTreeLoaded = (count, button, view) => {
          button.disabled = !count;
          if (count) {
            __privateMethod(this, _PDFSidebar_instances, showUINotification_fn).call(this);
          } else if (this.active === view) {
            this.switchView(_ui_utils.SidebarView.THUMBS);
          }
        };
        this.eventBus._on("outlineloaded", (evt) => {
          onTreeLoaded(evt.outlineCount, this.outlineButton, _ui_utils.SidebarView.OUTLINE);
          evt.currentOutlineItemPromise.then((enabled) => {
            if (!this.isInitialViewSet) {
              return;
            }
            this._currentOutlineItemButton.disabled = !enabled;
          });
        });
        this.eventBus._on("attachmentsloaded", (evt) => {
          onTreeLoaded(evt.attachmentsCount, this.attachmentsButton, _ui_utils.SidebarView.ATTACHMENTS);
        });
        this.eventBus._on("layersloaded", (evt) => {
          onTreeLoaded(evt.layersCount, this.layersButton, _ui_utils.SidebarView.LAYERS);
        });
        this.eventBus._on("presentationmodechanged", (evt) => {
          if (evt.state === _ui_utils.PresentationModeState.NORMAL && this.visibleView === _ui_utils.SidebarView.THUMBS) {
            __privateMethod(this, _PDFSidebar_instances, updateThumbnailViewer_fn).call(this);
          }
        });
      };
      exports.PDFSidebar = PDFSidebar;
    }),
    /* 25 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFSidebarResizer = void 0;
      var _ui_utils = __webpack_require__2(1);
      const SIDEBAR_WIDTH_VAR = "--sidebar-width";
      const SIDEBAR_MIN_WIDTH = 200;
      const SIDEBAR_RESIZING_CLASS = "sidebarResizing";
      class PDFSidebarResizer {
        constructor(options, eventBus, l10n) {
          this.isRTL = false;
          this.sidebarOpen = false;
          this._width = null;
          this._outerContainerWidth = null;
          this._boundEvents = /* @__PURE__ */ Object.create(null);
          this.outerContainer = options.outerContainer;
          this.resizer = options.resizer;
          this.eventBus = eventBus;
          l10n.getDirection().then((dir) => {
            this.isRTL = dir === "rtl";
          });
          this._addEventListeners();
        }
        get outerContainerWidth() {
          return this._outerContainerWidth || (this._outerContainerWidth = this.outerContainer.clientWidth);
        }
        _updateWidth(width = 0) {
          const maxWidth = Math.floor(this.outerContainerWidth / 2);
          if (width > maxWidth) {
            width = maxWidth;
          }
          if (width < SIDEBAR_MIN_WIDTH) {
            width = SIDEBAR_MIN_WIDTH;
          }
          if (width === this._width) {
            return false;
          }
          this._width = width;
          _ui_utils.docStyle.setProperty(SIDEBAR_WIDTH_VAR, `${width}px`);
          return true;
        }
        _mouseMove(evt) {
          let width = evt.clientX;
          if (this.isRTL) {
            width = this.outerContainerWidth - width;
          }
          this._updateWidth(width);
        }
        _mouseUp(evt) {
          this.outerContainer.classList.remove(SIDEBAR_RESIZING_CLASS);
          this.eventBus.dispatch("resize", {
            source: this
          });
          const _boundEvents = this._boundEvents;
          window.removeEventListener("mousemove", _boundEvents.mouseMove);
          window.removeEventListener("mouseup", _boundEvents.mouseUp);
        }
        _addEventListeners() {
          const _boundEvents = this._boundEvents;
          _boundEvents.mouseMove = this._mouseMove.bind(this);
          _boundEvents.mouseUp = this._mouseUp.bind(this);
          this.resizer.addEventListener("mousedown", (evt) => {
            if (evt.button !== 0) {
              return;
            }
            this.outerContainer.classList.add(SIDEBAR_RESIZING_CLASS);
            window.addEventListener("mousemove", _boundEvents.mouseMove);
            window.addEventListener("mouseup", _boundEvents.mouseUp);
          });
          this.eventBus._on("sidebarviewchanged", (evt) => {
            this.sidebarOpen = !!(evt == null ? void 0 : evt.view);
          });
          this.eventBus._on("resize", (evt) => {
            if ((evt == null ? void 0 : evt.source) !== window) {
              return;
            }
            this._outerContainerWidth = null;
            if (!this._width) {
              return;
            }
            if (!this.sidebarOpen) {
              this._updateWidth(this._width);
              return;
            }
            this.outerContainer.classList.add(SIDEBAR_RESIZING_CLASS);
            const updated = this._updateWidth(this._width);
            Promise.resolve().then(() => {
              this.outerContainer.classList.remove(SIDEBAR_RESIZING_CLASS);
              if (updated) {
                this.eventBus.dispatch("resize", {
                  source: this
                });
              }
            });
          });
        }
      }
      exports.PDFSidebarResizer = PDFSidebarResizer;
    }),
    /* 26 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _PDFThumbnailViewer_instances, ensurePdfPageLoaded_fn, getScrollAhead_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFThumbnailViewer = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _pdf_thumbnail_view = __webpack_require__2(27);
      const THUMBNAIL_SCROLL_MARGIN = -19;
      const THUMBNAIL_SELECTED_CLASS = "selected";
      class PDFThumbnailViewer {
        constructor({
          container,
          eventBus,
          linkService,
          renderingQueue,
          l10n,
          pageColors
        }) {
          __privateAdd(this, _PDFThumbnailViewer_instances);
          this.container = container;
          this.linkService = linkService;
          this.renderingQueue = renderingQueue;
          this.l10n = l10n;
          this.pageColors = pageColors || null;
          if (this.pageColors && !(CSS.supports("color", this.pageColors.background) && CSS.supports("color", this.pageColors.foreground))) {
            if (this.pageColors.background || this.pageColors.foreground) {
              console.warn("PDFThumbnailViewer: Ignoring `pageColors`-option, since the browser doesn't support the values used.");
            }
            this.pageColors = null;
          }
          this.scroll = (0, _ui_utils.watchScroll)(this.container, this._scrollUpdated.bind(this));
          this._resetView();
        }
        _scrollUpdated() {
          this.renderingQueue.renderHighestPriority();
        }
        getThumbnail(index) {
          return this._thumbnails[index];
        }
        _getVisibleThumbs() {
          return (0, _ui_utils.getVisibleElements)({
            scrollEl: this.container,
            views: this._thumbnails
          });
        }
        scrollThumbnailIntoView(pageNumber) {
          if (!this.pdfDocument) {
            return;
          }
          const thumbnailView = this._thumbnails[pageNumber - 1];
          if (!thumbnailView) {
            console.error('scrollThumbnailIntoView: Invalid "pageNumber" parameter.');
            return;
          }
          if (pageNumber !== this._currentPageNumber) {
            const prevThumbnailView = this._thumbnails[this._currentPageNumber - 1];
            prevThumbnailView.div.classList.remove(THUMBNAIL_SELECTED_CLASS);
            thumbnailView.div.classList.add(THUMBNAIL_SELECTED_CLASS);
          }
          const {
            first,
            last,
            views
          } = this._getVisibleThumbs();
          if (views.length > 0) {
            let shouldScroll = false;
            if (pageNumber <= first.id || pageNumber >= last.id) {
              shouldScroll = true;
            } else {
              for (const {
                id,
                percent
              } of views) {
                if (id !== pageNumber) {
                  continue;
                }
                shouldScroll = percent < 100;
                break;
              }
            }
            if (shouldScroll) {
              (0, _ui_utils.scrollIntoView)(thumbnailView.div, {
                top: THUMBNAIL_SCROLL_MARGIN
              });
            }
          }
          this._currentPageNumber = pageNumber;
        }
        get pagesRotation() {
          return this._pagesRotation;
        }
        set pagesRotation(rotation) {
          if (!(0, _ui_utils.isValidRotation)(rotation)) {
            throw new Error("Invalid thumbnails rotation angle.");
          }
          if (!this.pdfDocument) {
            return;
          }
          if (this._pagesRotation === rotation) {
            return;
          }
          this._pagesRotation = rotation;
          const updateArgs = {
            rotation
          };
          for (const thumbnail of this._thumbnails) {
            thumbnail.update(updateArgs);
          }
        }
        cleanup() {
          for (const thumbnail of this._thumbnails) {
            if (thumbnail.renderingState !== _ui_utils.RenderingStates.FINISHED) {
              thumbnail.reset();
            }
          }
          _pdf_thumbnail_view.TempImageFactory.destroyCanvas();
        }
        _resetView() {
          this._thumbnails = [];
          this._currentPageNumber = 1;
          this._pageLabels = null;
          this._pagesRotation = 0;
          this.container.textContent = "";
        }
        setDocument(pdfDocument) {
          if (this.pdfDocument) {
            this._cancelRendering();
            this._resetView();
          }
          this.pdfDocument = pdfDocument;
          if (!pdfDocument) {
            return;
          }
          const firstPagePromise = pdfDocument.getPage(1);
          const optionalContentConfigPromise = pdfDocument.getOptionalContentConfig();
          firstPagePromise.then((firstPdfPage) => {
            const pagesCount = pdfDocument.numPages;
            const viewport = firstPdfPage.getViewport({
              scale: 1
            });
            for (let pageNum = 1; pageNum <= pagesCount; ++pageNum) {
              const thumbnail = new _pdf_thumbnail_view.PDFThumbnailView({
                container: this.container,
                id: pageNum,
                defaultViewport: viewport.clone(),
                optionalContentConfigPromise,
                linkService: this.linkService,
                renderingQueue: this.renderingQueue,
                l10n: this.l10n,
                pageColors: this.pageColors
              });
              this._thumbnails.push(thumbnail);
            }
            const firstThumbnailView = this._thumbnails[0];
            if (firstThumbnailView) {
              firstThumbnailView.setPdfPage(firstPdfPage);
            }
            const thumbnailView = this._thumbnails[this._currentPageNumber - 1];
            thumbnailView.div.classList.add(THUMBNAIL_SELECTED_CLASS);
          }).catch((reason) => {
            console.error("Unable to initialize thumbnail viewer", reason);
          });
        }
        _cancelRendering() {
          for (const thumbnail of this._thumbnails) {
            thumbnail.cancelRendering();
          }
        }
        setPageLabels(labels) {
          var _a;
          if (!this.pdfDocument) {
            return;
          }
          if (!labels) {
            this._pageLabels = null;
          } else if (!(Array.isArray(labels) && this.pdfDocument.numPages === labels.length)) {
            this._pageLabels = null;
            console.error("PDFThumbnailViewer_setPageLabels: Invalid page labels.");
          } else {
            this._pageLabels = labels;
          }
          for (let i = 0, ii = this._thumbnails.length; i < ii; i++) {
            this._thumbnails[i].setPageLabel(((_a = this._pageLabels) == null ? void 0 : _a[i]) ?? null);
          }
        }
        forceRendering() {
          const visibleThumbs = this._getVisibleThumbs();
          const scrollAhead = __privateMethod(this, _PDFThumbnailViewer_instances, getScrollAhead_fn).call(this, visibleThumbs);
          const thumbView = this.renderingQueue.getHighestPriority(visibleThumbs, this._thumbnails, scrollAhead);
          if (thumbView) {
            __privateMethod(this, _PDFThumbnailViewer_instances, ensurePdfPageLoaded_fn).call(this, thumbView).then(() => {
              this.renderingQueue.renderView(thumbView);
            });
            return true;
          }
          return false;
        }
      }
      _PDFThumbnailViewer_instances = new WeakSet();
      ensurePdfPageLoaded_fn = async function(thumbView) {
        if (thumbView.pdfPage) {
          return thumbView.pdfPage;
        }
        try {
          const pdfPage = await this.pdfDocument.getPage(thumbView.id);
          if (!thumbView.pdfPage) {
            thumbView.setPdfPage(pdfPage);
          }
          return pdfPage;
        } catch (reason) {
          console.error("Unable to get page for thumb view", reason);
          return null;
        }
      };
      getScrollAhead_fn = function(visible) {
        var _a, _b;
        if (((_a = visible.first) == null ? void 0 : _a.id) === 1) {
          return true;
        } else if (((_b = visible.last) == null ? void 0 : _b.id) === this._thumbnails.length) {
          return false;
        }
        return this.scroll.down;
      };
      exports.PDFThumbnailViewer = PDFThumbnailViewer;
    }),
    /* 27 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.TempImageFactory = exports.PDFThumbnailView = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _pdfjsLib = __webpack_require__2(5);
      const DRAW_UPSCALE_FACTOR = 2;
      const MAX_NUM_SCALING_STEPS = 3;
      const THUMBNAIL_CANVAS_BORDER_WIDTH = 1;
      const THUMBNAIL_WIDTH = 98;
      class TempImageFactory {
        static #tempCanvas = null;
        static getCanvas(width, height) {
          const tempCanvas = this.#tempCanvas || (this.#tempCanvas = document.createElement("canvas"));
          tempCanvas.width = width;
          tempCanvas.height = height;
          const ctx = tempCanvas.getContext("2d", {
            alpha: false
          });
          ctx.save();
          ctx.fillStyle = "rgb(255, 255, 255)";
          ctx.fillRect(0, 0, width, height);
          ctx.restore();
          return [tempCanvas, tempCanvas.getContext("2d")];
        }
        static destroyCanvas() {
          const tempCanvas = this.#tempCanvas;
          if (tempCanvas) {
            tempCanvas.width = 0;
            tempCanvas.height = 0;
          }
          this.#tempCanvas = null;
        }
      }
      exports.TempImageFactory = TempImageFactory;
      class PDFThumbnailView {
        constructor({
          container,
          id,
          defaultViewport,
          optionalContentConfigPromise,
          linkService,
          renderingQueue,
          l10n,
          pageColors
        }) {
          this.id = id;
          this.renderingId = "thumbnail" + id;
          this.pageLabel = null;
          this.pdfPage = null;
          this.rotation = 0;
          this.viewport = defaultViewport;
          this.pdfPageRotate = defaultViewport.rotation;
          this._optionalContentConfigPromise = optionalContentConfigPromise || null;
          this.pageColors = pageColors || null;
          this.linkService = linkService;
          this.renderingQueue = renderingQueue;
          this.renderTask = null;
          this.renderingState = _ui_utils.RenderingStates.INITIAL;
          this.resume = null;
          const pageWidth = this.viewport.width, pageHeight = this.viewport.height, pageRatio = pageWidth / pageHeight;
          this.canvasWidth = THUMBNAIL_WIDTH;
          this.canvasHeight = this.canvasWidth / pageRatio | 0;
          this.scale = this.canvasWidth / pageWidth;
          this.l10n = l10n;
          const anchor = document.createElement("a");
          anchor.href = linkService.getAnchorUrl("#page=" + id);
          this._thumbPageTitle.then((msg) => {
            anchor.title = msg;
          });
          anchor.onclick = function() {
            linkService.goToPage(id);
            return false;
          };
          this.anchor = anchor;
          const div = document.createElement("div");
          div.className = "thumbnail";
          div.setAttribute("data-page-number", this.id);
          this.div = div;
          const ring = document.createElement("div");
          ring.className = "thumbnailSelectionRing";
          const borderAdjustment = 2 * THUMBNAIL_CANVAS_BORDER_WIDTH;
          ring.style.width = this.canvasWidth + borderAdjustment + "px";
          ring.style.height = this.canvasHeight + borderAdjustment + "px";
          this.ring = ring;
          div.append(ring);
          anchor.append(div);
          container.append(anchor);
        }
        setPdfPage(pdfPage) {
          this.pdfPage = pdfPage;
          this.pdfPageRotate = pdfPage.rotate;
          const totalRotation = (this.rotation + this.pdfPageRotate) % 360;
          this.viewport = pdfPage.getViewport({
            scale: 1,
            rotation: totalRotation
          });
          this.reset();
        }
        reset() {
          this.cancelRendering();
          this.renderingState = _ui_utils.RenderingStates.INITIAL;
          const pageWidth = this.viewport.width, pageHeight = this.viewport.height, pageRatio = pageWidth / pageHeight;
          this.canvasHeight = this.canvasWidth / pageRatio | 0;
          this.scale = this.canvasWidth / pageWidth;
          this.div.removeAttribute("data-loaded");
          const ring = this.ring;
          ring.textContent = "";
          const borderAdjustment = 2 * THUMBNAIL_CANVAS_BORDER_WIDTH;
          ring.style.width = this.canvasWidth + borderAdjustment + "px";
          ring.style.height = this.canvasHeight + borderAdjustment + "px";
          if (this.canvas) {
            this.canvas.width = 0;
            this.canvas.height = 0;
            delete this.canvas;
          }
          if (this.image) {
            this.image.removeAttribute("src");
            delete this.image;
          }
        }
        update({
          rotation = null
        }) {
          if (typeof rotation === "number") {
            this.rotation = rotation;
          }
          const totalRotation = (this.rotation + this.pdfPageRotate) % 360;
          this.viewport = this.viewport.clone({
            scale: 1,
            rotation: totalRotation
          });
          this.reset();
        }
        cancelRendering() {
          if (this.renderTask) {
            this.renderTask.cancel();
            this.renderTask = null;
          }
          this.resume = null;
        }
        _getPageDrawContext(upscaleFactor = 1) {
          const canvas = document.createElement("canvas");
          const ctx = canvas.getContext("2d", {
            alpha: false
          });
          const outputScale = new _ui_utils.OutputScale();
          canvas.width = upscaleFactor * this.canvasWidth * outputScale.sx | 0;
          canvas.height = upscaleFactor * this.canvasHeight * outputScale.sy | 0;
          const transform = outputScale.scaled ? [outputScale.sx, 0, 0, outputScale.sy, 0, 0] : null;
          return {
            ctx,
            canvas,
            transform
          };
        }
        _convertCanvasToImage(canvas) {
          if (this.renderingState !== _ui_utils.RenderingStates.FINISHED) {
            throw new Error("_convertCanvasToImage: Rendering has not finished.");
          }
          const reducedCanvas = this._reduceImage(canvas);
          const image = document.createElement("img");
          image.className = "thumbnailImage";
          this._thumbPageCanvas.then((msg) => {
            image.setAttribute("aria-label", msg);
          });
          image.style.width = this.canvasWidth + "px";
          image.style.height = this.canvasHeight + "px";
          image.src = reducedCanvas.toDataURL();
          this.image = image;
          this.div.setAttribute("data-loaded", true);
          this.ring.append(image);
          reducedCanvas.width = 0;
          reducedCanvas.height = 0;
        }
        draw() {
          if (this.renderingState !== _ui_utils.RenderingStates.INITIAL) {
            console.error("Must be in new state before drawing");
            return Promise.resolve();
          }
          const {
            pdfPage
          } = this;
          if (!pdfPage) {
            this.renderingState = _ui_utils.RenderingStates.FINISHED;
            return Promise.reject(new Error("pdfPage is not loaded"));
          }
          this.renderingState = _ui_utils.RenderingStates.RUNNING;
          const finishRenderTask = async (error = null) => {
            if (renderTask === this.renderTask) {
              this.renderTask = null;
            }
            if (error instanceof _pdfjsLib.RenderingCancelledException) {
              return;
            }
            this.renderingState = _ui_utils.RenderingStates.FINISHED;
            this._convertCanvasToImage(canvas);
            if (error) {
              throw error;
            }
          };
          const {
            ctx,
            canvas,
            transform
          } = this._getPageDrawContext(DRAW_UPSCALE_FACTOR);
          const drawViewport = this.viewport.clone({
            scale: DRAW_UPSCALE_FACTOR * this.scale
          });
          const renderContinueCallback = (cont) => {
            if (!this.renderingQueue.isHighestPriority(this)) {
              this.renderingState = _ui_utils.RenderingStates.PAUSED;
              this.resume = () => {
                this.renderingState = _ui_utils.RenderingStates.RUNNING;
                cont();
              };
              return;
            }
            cont();
          };
          const renderContext = {
            canvasContext: ctx,
            transform,
            viewport: drawViewport,
            optionalContentConfigPromise: this._optionalContentConfigPromise,
            pageColors: this.pageColors
          };
          const renderTask = this.renderTask = pdfPage.render(renderContext);
          renderTask.onContinue = renderContinueCallback;
          const resultPromise = renderTask.promise.then(function() {
            return finishRenderTask(null);
          }, function(error) {
            return finishRenderTask(error);
          });
          resultPromise.finally(() => {
            var _a;
            canvas.width = 0;
            canvas.height = 0;
            const pageCached = this.linkService.isPageCached(this.id);
            if (!pageCached) {
              (_a = this.pdfPage) == null ? void 0 : _a.cleanup();
            }
          });
          return resultPromise;
        }
        setImage(pageView) {
          if (this.renderingState !== _ui_utils.RenderingStates.INITIAL) {
            return;
          }
          const {
            thumbnailCanvas: canvas,
            pdfPage,
            scale
          } = pageView;
          if (!canvas) {
            return;
          }
          if (!this.pdfPage) {
            this.setPdfPage(pdfPage);
          }
          if (scale < this.scale) {
            return;
          }
          this.renderingState = _ui_utils.RenderingStates.FINISHED;
          this._convertCanvasToImage(canvas);
        }
        _reduceImage(img) {
          const {
            ctx,
            canvas
          } = this._getPageDrawContext();
          if (img.width <= 2 * canvas.width) {
            ctx.drawImage(img, 0, 0, img.width, img.height, 0, 0, canvas.width, canvas.height);
            return canvas;
          }
          let reducedWidth = canvas.width << MAX_NUM_SCALING_STEPS;
          let reducedHeight = canvas.height << MAX_NUM_SCALING_STEPS;
          const [reducedImage, reducedImageCtx] = TempImageFactory.getCanvas(reducedWidth, reducedHeight);
          while (reducedWidth > img.width || reducedHeight > img.height) {
            reducedWidth >>= 1;
            reducedHeight >>= 1;
          }
          reducedImageCtx.drawImage(img, 0, 0, img.width, img.height, 0, 0, reducedWidth, reducedHeight);
          while (reducedWidth > 2 * canvas.width) {
            reducedImageCtx.drawImage(reducedImage, 0, 0, reducedWidth, reducedHeight, 0, 0, reducedWidth >> 1, reducedHeight >> 1);
            reducedWidth >>= 1;
            reducedHeight >>= 1;
          }
          ctx.drawImage(reducedImage, 0, 0, reducedWidth, reducedHeight, 0, 0, canvas.width, canvas.height);
          return canvas;
        }
        get _thumbPageTitle() {
          return this.l10n.get("thumb_page_title", {
            page: this.pageLabel ?? this.id
          });
        }
        get _thumbPageCanvas() {
          return this.l10n.get("thumb_page_canvas", {
            page: this.pageLabel ?? this.id
          });
        }
        setPageLabel(label) {
          this.pageLabel = typeof label === "string" ? label : null;
          this._thumbPageTitle.then((msg) => {
            this.anchor.title = msg;
          });
          if (this.renderingState !== _ui_utils.RenderingStates.FINISHED) {
            return;
          }
          this._thumbPageCanvas.then((msg) => {
            var _a;
            (_a = this.image) == null ? void 0 : _a.setAttribute("aria-label", msg);
          });
        }
      }
      exports.PDFThumbnailView = PDFThumbnailView;
    }),
    /* 28 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFViewer = exports.PDFSinglePageViewer = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _base_viewer = __webpack_require__2(29);
      class PDFViewer extends _base_viewer.BaseViewer {
      }
      exports.PDFViewer = PDFViewer;
      class PDFSinglePageViewer extends _base_viewer.BaseViewer {
        _resetView() {
          super._resetView();
          this._scrollMode = _ui_utils.ScrollMode.PAGE;
          this._spreadMode = _ui_utils.SpreadMode.NONE;
        }
        set scrollMode(mode) {
        }
        _updateScrollMode() {
        }
        set spreadMode(mode) {
        }
        _updateSpreadMode() {
        }
      }
      exports.PDFSinglePageViewer = PDFSinglePageViewer;
    }),
    /* 29 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _buf, _size, _PDFPageViewBuffer_instances, destroyFirstView_fn, _buffer, _annotationEditorMode, _annotationEditorUIManager, _annotationMode, _enablePermissions, _previousContainerHeight, _scrollModePageState, _onVisibilityChange, _BaseViewer_instances, initializePermissions_fn, onePageRenderedOrForceFetch_fn, ensurePageViewVisible_fn, scrollIntoView_fn, isSameScale_fn, resetCurrentPageView_fn, ensurePdfPageLoaded_fn, getScrollAhead_fn, toggleLoadingIconSpinner_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PagesCountLimit = exports.PDFPageViewBuffer = exports.BaseViewer = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      var _ui_utils = __webpack_require__2(1);
      var _annotation_editor_layer_builder = __webpack_require__2(30);
      var _annotation_layer_builder = __webpack_require__2(32);
      var _l10n_utils = __webpack_require__2(31);
      var _pdf_page_view = __webpack_require__2(33);
      var _pdf_rendering_queue = __webpack_require__2(22);
      var _pdf_link_service = __webpack_require__2(3);
      var _struct_tree_layer_builder = __webpack_require__2(35);
      var _text_highlighter = __webpack_require__2(36);
      var _text_layer_builder = __webpack_require__2(37);
      var _xfa_layer_builder = __webpack_require__2(38);
      const DEFAULT_CACHE_SIZE = 10;
      const ENABLE_PERMISSIONS_CLASS = "enablePermissions";
      const PagesCountLimit = {
        FORCE_SCROLL_MODE_PAGE: 15e3,
        FORCE_LAZY_PAGE_INIT: 7500,
        PAUSE_EAGER_PAGE_INIT: 250
      };
      exports.PagesCountLimit = PagesCountLimit;
      function isValidAnnotationEditorMode(mode) {
        return Object.values(_pdfjsLib.AnnotationEditorType).includes(mode) && mode !== _pdfjsLib.AnnotationEditorType.DISABLE;
      }
      class PDFPageViewBuffer {
        constructor(size) {
          __privateAdd(this, _PDFPageViewBuffer_instances);
          __privateAdd(this, _buf, /* @__PURE__ */ new Set());
          __privateAdd(this, _size, 0);
          __privateSet(this, _size, size);
        }
        push(view) {
          const buf = __privateGet(this, _buf);
          if (buf.has(view)) {
            buf.delete(view);
          }
          buf.add(view);
          if (buf.size > __privateGet(this, _size)) {
            __privateMethod(this, _PDFPageViewBuffer_instances, destroyFirstView_fn).call(this);
          }
        }
        resize(newSize, idsToKeep = null) {
          __privateSet(this, _size, newSize);
          const buf = __privateGet(this, _buf);
          if (idsToKeep) {
            const ii = buf.size;
            let i = 1;
            for (const view of buf) {
              if (idsToKeep.has(view.id)) {
                buf.delete(view);
                buf.add(view);
              }
              if (++i > ii) {
                break;
              }
            }
          }
          while (buf.size > __privateGet(this, _size)) {
            __privateMethod(this, _PDFPageViewBuffer_instances, destroyFirstView_fn).call(this);
          }
        }
        has(view) {
          return __privateGet(this, _buf).has(view);
        }
        [Symbol.iterator]() {
          return __privateGet(this, _buf).keys();
        }
      }
      _buf = new WeakMap();
      _size = new WeakMap();
      _PDFPageViewBuffer_instances = new WeakSet();
      destroyFirstView_fn = function() {
        const firstView = __privateGet(this, _buf).keys().next().value;
        firstView == null ? void 0 : firstView.destroy();
        __privateGet(this, _buf).delete(firstView);
      };
      exports.PDFPageViewBuffer = PDFPageViewBuffer;
      const _BaseViewer = class _BaseViewer {
        constructor(options) {
          __privateAdd(this, _BaseViewer_instances);
          __privateAdd(this, _buffer, null);
          __privateAdd(this, _annotationEditorMode, _pdfjsLib.AnnotationEditorType.DISABLE);
          __privateAdd(this, _annotationEditorUIManager, null);
          __privateAdd(this, _annotationMode, _pdfjsLib.AnnotationMode.ENABLE_FORMS);
          __privateAdd(this, _enablePermissions, false);
          __privateAdd(this, _previousContainerHeight, 0);
          __privateAdd(this, _scrollModePageState, null);
          __privateAdd(this, _onVisibilityChange, null);
          var _a, _b;
          if (this.constructor === _BaseViewer) {
            throw new Error("Cannot initialize BaseViewer.");
          }
          const viewerVersion = "2.16.105";
          if (_pdfjsLib.version !== viewerVersion) {
            throw new Error(`The API version "${_pdfjsLib.version}" does not match the Viewer version "${viewerVersion}".`);
          }
          this.container = options.container;
          this.viewer = options.viewer || options.container.firstElementChild;
          if (!(((_a = this.container) == null ? void 0 : _a.tagName.toUpperCase()) === "DIV" && ((_b = this.viewer) == null ? void 0 : _b.tagName.toUpperCase()) === "DIV")) {
            throw new Error("Invalid `container` and/or `viewer` option.");
          }
          if (this.container.offsetParent && getComputedStyle(this.container).position !== "absolute") {
            throw new Error("The `container` must be absolutely positioned.");
          }
          this.eventBus = options.eventBus;
          this.linkService = options.linkService || new _pdf_link_service.SimpleLinkService();
          this.downloadManager = options.downloadManager || null;
          this.findController = options.findController || null;
          this._scriptingManager = options.scriptingManager || null;
          this.removePageBorders = options.removePageBorders || false;
          this.textLayerMode = options.textLayerMode ?? _ui_utils.TextLayerMode.ENABLE;
          __privateSet(this, _annotationMode, options.annotationMode ?? _pdfjsLib.AnnotationMode.ENABLE_FORMS);
          __privateSet(this, _annotationEditorMode, options.annotationEditorMode ?? _pdfjsLib.AnnotationEditorType.DISABLE);
          this.imageResourcesPath = options.imageResourcesPath || "";
          this.enablePrintAutoRotate = options.enablePrintAutoRotate || false;
          this.renderer = options.renderer || _ui_utils.RendererType.CANVAS;
          this.useOnlyCssZoom = options.useOnlyCssZoom || false;
          this.maxCanvasPixels = options.maxCanvasPixels;
          this.l10n = options.l10n || _l10n_utils.NullL10n;
          __privateSet(this, _enablePermissions, options.enablePermissions || false);
          this.pageColors = options.pageColors || null;
          if (this.pageColors && !(CSS.supports("color", this.pageColors.background) && CSS.supports("color", this.pageColors.foreground))) {
            if (this.pageColors.background || this.pageColors.foreground) {
              console.warn("BaseViewer: Ignoring `pageColors`-option, since the browser doesn't support the values used.");
            }
            this.pageColors = null;
          }
          this.defaultRenderingQueue = !options.renderingQueue;
          if (this.defaultRenderingQueue) {
            this.renderingQueue = new _pdf_rendering_queue.PDFRenderingQueue();
            this.renderingQueue.setViewer(this);
          } else {
            this.renderingQueue = options.renderingQueue;
          }
          this.scroll = (0, _ui_utils.watchScroll)(this.container, this._scrollUpdate.bind(this));
          this.presentationModeState = _ui_utils.PresentationModeState.UNKNOWN;
          this._onBeforeDraw = this._onAfterDraw = null;
          this._resetView();
          if (this.removePageBorders) {
            this.viewer.classList.add("removePageBorders");
          }
          this.updateContainerHeightCss();
        }
        get pagesCount() {
          return this._pages.length;
        }
        getPageView(index) {
          return this._pages[index];
        }
        get pageViewsReady() {
          if (!this._pagesCapability.settled) {
            return false;
          }
          return this._pages.every(function(pageView) {
            return pageView == null ? void 0 : pageView.pdfPage;
          });
        }
        get renderForms() {
          return __privateGet(this, _annotationMode) === _pdfjsLib.AnnotationMode.ENABLE_FORMS;
        }
        get enableScripting() {
          return !!this._scriptingManager;
        }
        get currentPageNumber() {
          return this._currentPageNumber;
        }
        set currentPageNumber(val) {
          if (!Number.isInteger(val)) {
            throw new Error("Invalid page number.");
          }
          if (!this.pdfDocument) {
            return;
          }
          if (!this._setCurrentPageNumber(val, true)) {
            console.error(`currentPageNumber: "${val}" is not a valid page.`);
          }
        }
        _setCurrentPageNumber(val, resetCurrentPageView = false) {
          var _a;
          if (this._currentPageNumber === val) {
            if (resetCurrentPageView) {
              __privateMethod(this, _BaseViewer_instances, resetCurrentPageView_fn).call(this);
            }
            return true;
          }
          if (!(0 < val && val <= this.pagesCount)) {
            return false;
          }
          const previous = this._currentPageNumber;
          this._currentPageNumber = val;
          this.eventBus.dispatch("pagechanging", {
            source: this,
            pageNumber: val,
            pageLabel: ((_a = this._pageLabels) == null ? void 0 : _a[val - 1]) ?? null,
            previous
          });
          if (resetCurrentPageView) {
            __privateMethod(this, _BaseViewer_instances, resetCurrentPageView_fn).call(this);
          }
          return true;
        }
        get currentPageLabel() {
          var _a;
          return ((_a = this._pageLabels) == null ? void 0 : _a[this._currentPageNumber - 1]) ?? null;
        }
        set currentPageLabel(val) {
          if (!this.pdfDocument) {
            return;
          }
          let page = val | 0;
          if (this._pageLabels) {
            const i = this._pageLabels.indexOf(val);
            if (i >= 0) {
              page = i + 1;
            }
          }
          if (!this._setCurrentPageNumber(page, true)) {
            console.error(`currentPageLabel: "${val}" is not a valid page.`);
          }
        }
        get currentScale() {
          return this._currentScale !== _ui_utils.UNKNOWN_SCALE ? this._currentScale : _ui_utils.DEFAULT_SCALE;
        }
        set currentScale(val) {
          if (isNaN(val)) {
            throw new Error("Invalid numeric scale.");
          }
          if (!this.pdfDocument) {
            return;
          }
          this._setScale(val, false);
        }
        get currentScaleValue() {
          return this._currentScaleValue;
        }
        set currentScaleValue(val) {
          if (!this.pdfDocument) {
            return;
          }
          this._setScale(val, false);
        }
        get pagesRotation() {
          return this._pagesRotation;
        }
        set pagesRotation(rotation) {
          if (!(0, _ui_utils.isValidRotation)(rotation)) {
            throw new Error("Invalid pages rotation angle.");
          }
          if (!this.pdfDocument) {
            return;
          }
          rotation %= 360;
          if (rotation < 0) {
            rotation += 360;
          }
          if (this._pagesRotation === rotation) {
            return;
          }
          this._pagesRotation = rotation;
          const pageNumber = this._currentPageNumber;
          const updateArgs = {
            rotation
          };
          for (const pageView of this._pages) {
            pageView.update(updateArgs);
          }
          if (this._currentScaleValue) {
            this._setScale(this._currentScaleValue, true);
          }
          this.eventBus.dispatch("rotationchanging", {
            source: this,
            pagesRotation: rotation,
            pageNumber
          });
          if (this.defaultRenderingQueue) {
            this.update();
          }
        }
        get firstPagePromise() {
          return this.pdfDocument ? this._firstPageCapability.promise : null;
        }
        get onePageRendered() {
          return this.pdfDocument ? this._onePageRenderedCapability.promise : null;
        }
        get pagesPromise() {
          return this.pdfDocument ? this._pagesCapability.promise : null;
        }
        setDocument(pdfDocument) {
          if (this.pdfDocument) {
            this.eventBus.dispatch("pagesdestroy", {
              source: this
            });
            this._cancelRendering();
            this._resetView();
            if (this.findController) {
              this.findController.setDocument(null);
            }
            if (this._scriptingManager) {
              this._scriptingManager.setDocument(null);
            }
            if (__privateGet(this, _annotationEditorUIManager)) {
              __privateGet(this, _annotationEditorUIManager).destroy();
              __privateSet(this, _annotationEditorUIManager, null);
            }
          }
          this.pdfDocument = pdfDocument;
          if (!pdfDocument) {
            return;
          }
          const isPureXfa = pdfDocument.isPureXfa;
          const pagesCount = pdfDocument.numPages;
          const firstPagePromise = pdfDocument.getPage(1);
          const optionalContentConfigPromise = pdfDocument.getOptionalContentConfig();
          const permissionsPromise = __privateGet(this, _enablePermissions) ? pdfDocument.getPermissions() : Promise.resolve();
          if (pagesCount > PagesCountLimit.FORCE_SCROLL_MODE_PAGE) {
            console.warn("Forcing PAGE-scrolling for performance reasons, given the length of the document.");
            const mode = this._scrollMode = _ui_utils.ScrollMode.PAGE;
            this.eventBus.dispatch("scrollmodechanged", {
              source: this,
              mode
            });
          }
          this._pagesCapability.promise.then(() => {
            this.eventBus.dispatch("pagesloaded", {
              source: this,
              pagesCount
            });
          }, () => {
          });
          this._onBeforeDraw = (evt) => {
            const pageView = this._pages[evt.pageNumber - 1];
            if (!pageView) {
              return;
            }
            __privateGet(this, _buffer).push(pageView);
          };
          this.eventBus._on("pagerender", this._onBeforeDraw);
          this._onAfterDraw = (evt) => {
            if (evt.cssTransform || this._onePageRenderedCapability.settled) {
              return;
            }
            this._onePageRenderedCapability.resolve({
              timestamp: evt.timestamp
            });
            this.eventBus._off("pagerendered", this._onAfterDraw);
            this._onAfterDraw = null;
            if (__privateGet(this, _onVisibilityChange)) {
              document.removeEventListener("visibilitychange", __privateGet(this, _onVisibilityChange));
              __privateSet(this, _onVisibilityChange, null);
            }
          };
          this.eventBus._on("pagerendered", this._onAfterDraw);
          Promise.all([firstPagePromise, permissionsPromise]).then(([firstPdfPage, permissions]) => {
            if (pdfDocument !== this.pdfDocument) {
              return;
            }
            this._firstPageCapability.resolve(firstPdfPage);
            this._optionalContentConfigPromise = optionalContentConfigPromise;
            const {
              annotationEditorMode,
              annotationMode,
              textLayerMode
            } = __privateMethod(this, _BaseViewer_instances, initializePermissions_fn).call(this, permissions);
            if (annotationEditorMode !== _pdfjsLib.AnnotationEditorType.DISABLE) {
              const mode = annotationEditorMode;
              if (isPureXfa) {
                console.warn("Warning: XFA-editing is not implemented.");
              } else if (isValidAnnotationEditorMode(mode)) {
                __privateSet(this, _annotationEditorUIManager, new _pdfjsLib.AnnotationEditorUIManager(this.container, this.eventBus));
                if (mode !== _pdfjsLib.AnnotationEditorType.NONE) {
                  __privateGet(this, _annotationEditorUIManager).updateMode(mode);
                }
              } else {
                console.error(`Invalid AnnotationEditor mode: ${mode}`);
              }
            }
            const viewerElement = this._scrollMode === _ui_utils.ScrollMode.PAGE ? null : this.viewer;
            const scale = this.currentScale;
            const viewport = firstPdfPage.getViewport({
              scale: scale * _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS
            });
            const textLayerFactory = textLayerMode !== _ui_utils.TextLayerMode.DISABLE && !isPureXfa ? this : null;
            const annotationLayerFactory = annotationMode !== _pdfjsLib.AnnotationMode.DISABLE ? this : null;
            const xfaLayerFactory = isPureXfa ? this : null;
            const annotationEditorLayerFactory = __privateGet(this, _annotationEditorUIManager) ? this : null;
            for (let pageNum = 1; pageNum <= pagesCount; ++pageNum) {
              const pageView = new _pdf_page_view.PDFPageView({
                container: viewerElement,
                eventBus: this.eventBus,
                id: pageNum,
                scale,
                defaultViewport: viewport.clone(),
                optionalContentConfigPromise,
                renderingQueue: this.renderingQueue,
                textLayerFactory,
                textLayerMode,
                annotationLayerFactory,
                annotationMode,
                xfaLayerFactory,
                annotationEditorLayerFactory,
                textHighlighterFactory: this,
                structTreeLayerFactory: this,
                imageResourcesPath: this.imageResourcesPath,
                renderer: this.renderer,
                useOnlyCssZoom: this.useOnlyCssZoom,
                maxCanvasPixels: this.maxCanvasPixels,
                pageColors: this.pageColors,
                l10n: this.l10n
              });
              this._pages.push(pageView);
            }
            const firstPageView = this._pages[0];
            if (firstPageView) {
              firstPageView.setPdfPage(firstPdfPage);
              this.linkService.cachePageRef(1, firstPdfPage.ref);
            }
            if (this._scrollMode === _ui_utils.ScrollMode.PAGE) {
              __privateMethod(this, _BaseViewer_instances, ensurePageViewVisible_fn).call(this);
            } else if (this._spreadMode !== _ui_utils.SpreadMode.NONE) {
              this._updateSpreadMode();
            }
            __privateMethod(this, _BaseViewer_instances, onePageRenderedOrForceFetch_fn).call(this).then(async () => {
              if (this.findController) {
                this.findController.setDocument(pdfDocument);
              }
              if (this._scriptingManager) {
                this._scriptingManager.setDocument(pdfDocument);
              }
              if (__privateGet(this, _annotationEditorUIManager)) {
                this.eventBus.dispatch("annotationeditormodechanged", {
                  source: this,
                  mode: __privateGet(this, _annotationEditorMode)
                });
              }
              if (pdfDocument.loadingParams.disableAutoFetch || pagesCount > PagesCountLimit.FORCE_LAZY_PAGE_INIT) {
                this._pagesCapability.resolve();
                return;
              }
              let getPagesLeft = pagesCount - 1;
              if (getPagesLeft <= 0) {
                this._pagesCapability.resolve();
                return;
              }
              for (let pageNum = 2; pageNum <= pagesCount; ++pageNum) {
                const promise = pdfDocument.getPage(pageNum).then((pdfPage) => {
                  const pageView = this._pages[pageNum - 1];
                  if (!pageView.pdfPage) {
                    pageView.setPdfPage(pdfPage);
                  }
                  this.linkService.cachePageRef(pageNum, pdfPage.ref);
                  if (--getPagesLeft === 0) {
                    this._pagesCapability.resolve();
                  }
                }, (reason) => {
                  console.error(`Unable to get page ${pageNum} to initialize viewer`, reason);
                  if (--getPagesLeft === 0) {
                    this._pagesCapability.resolve();
                  }
                });
                if (pageNum % PagesCountLimit.PAUSE_EAGER_PAGE_INIT === 0) {
                  await promise;
                }
              }
            });
            this.eventBus.dispatch("pagesinit", {
              source: this
            });
            pdfDocument.getMetadata().then(({
              info
            }) => {
              if (pdfDocument !== this.pdfDocument) {
                return;
              }
              if (info.Language) {
                this.viewer.lang = info.Language;
              }
            });
            if (this.defaultRenderingQueue) {
              this.update();
            }
          }).catch((reason) => {
            console.error("Unable to initialize viewer", reason);
            this._pagesCapability.reject(reason);
          });
        }
        setPageLabels(labels) {
          var _a;
          if (!this.pdfDocument) {
            return;
          }
          if (!labels) {
            this._pageLabels = null;
          } else if (!(Array.isArray(labels) && this.pdfDocument.numPages === labels.length)) {
            this._pageLabels = null;
            console.error(`setPageLabels: Invalid page labels.`);
          } else {
            this._pageLabels = labels;
          }
          for (let i = 0, ii = this._pages.length; i < ii; i++) {
            this._pages[i].setPageLabel(((_a = this._pageLabels) == null ? void 0 : _a[i]) ?? null);
          }
        }
        _resetView() {
          this._pages = [];
          this._currentPageNumber = 1;
          this._currentScale = _ui_utils.UNKNOWN_SCALE;
          this._currentScaleValue = null;
          this._pageLabels = null;
          __privateSet(this, _buffer, new PDFPageViewBuffer(DEFAULT_CACHE_SIZE));
          this._location = null;
          this._pagesRotation = 0;
          this._optionalContentConfigPromise = null;
          this._firstPageCapability = (0, _pdfjsLib.createPromiseCapability)();
          this._onePageRenderedCapability = (0, _pdfjsLib.createPromiseCapability)();
          this._pagesCapability = (0, _pdfjsLib.createPromiseCapability)();
          this._scrollMode = _ui_utils.ScrollMode.VERTICAL;
          this._previousScrollMode = _ui_utils.ScrollMode.UNKNOWN;
          this._spreadMode = _ui_utils.SpreadMode.NONE;
          __privateSet(this, _scrollModePageState, {
            previousPageNumber: 1,
            scrollDown: true,
            pages: []
          });
          if (this._onBeforeDraw) {
            this.eventBus._off("pagerender", this._onBeforeDraw);
            this._onBeforeDraw = null;
          }
          if (this._onAfterDraw) {
            this.eventBus._off("pagerendered", this._onAfterDraw);
            this._onAfterDraw = null;
          }
          if (__privateGet(this, _onVisibilityChange)) {
            document.removeEventListener("visibilitychange", __privateGet(this, _onVisibilityChange));
            __privateSet(this, _onVisibilityChange, null);
          }
          this.viewer.textContent = "";
          this._updateScrollMode();
          this.viewer.removeAttribute("lang");
          this.viewer.classList.remove(ENABLE_PERMISSIONS_CLASS);
        }
        _scrollUpdate() {
          if (this.pagesCount === 0) {
            return;
          }
          this.update();
        }
        _setScaleUpdatePages(newScale, newValue, noScroll = false, preset = false) {
          this._currentScaleValue = newValue.toString();
          if (__privateMethod(this, _BaseViewer_instances, isSameScale_fn).call(this, newScale)) {
            if (preset) {
              this.eventBus.dispatch("scalechanging", {
                source: this,
                scale: newScale,
                presetValue: newValue
              });
            }
            return;
          }
          _ui_utils.docStyle.setProperty("--scale-factor", newScale * _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS);
          const updateArgs = {
            scale: newScale
          };
          for (const pageView of this._pages) {
            pageView.update(updateArgs);
          }
          this._currentScale = newScale;
          if (!noScroll) {
            let page = this._currentPageNumber, dest;
            if (this._location && !(this.isInPresentationMode || this.isChangingPresentationMode)) {
              page = this._location.pageNumber;
              dest = [null, {
                name: "XYZ"
              }, this._location.left, this._location.top, null];
            }
            this.scrollPageIntoView({
              pageNumber: page,
              destArray: dest,
              allowNegativeOffset: true
            });
          }
          this.eventBus.dispatch("scalechanging", {
            source: this,
            scale: newScale,
            presetValue: preset ? newValue : void 0
          });
          if (this.defaultRenderingQueue) {
            this.update();
          }
          this.updateContainerHeightCss();
        }
        get _pageWidthScaleFactor() {
          if (this._spreadMode !== _ui_utils.SpreadMode.NONE && this._scrollMode !== _ui_utils.ScrollMode.HORIZONTAL) {
            return 2;
          }
          return 1;
        }
        _setScale(value, noScroll = false) {
          let scale = parseFloat(value);
          if (scale > 0) {
            this._setScaleUpdatePages(scale, value, noScroll, false);
          } else {
            const currentPage = this._pages[this._currentPageNumber - 1];
            if (!currentPage) {
              return;
            }
            let hPadding = _ui_utils.SCROLLBAR_PADDING, vPadding = _ui_utils.VERTICAL_PADDING;
            if (this.isInPresentationMode) {
              hPadding = vPadding = 4;
            } else if (this.removePageBorders) {
              hPadding = vPadding = 0;
            } else if (this._scrollMode === _ui_utils.ScrollMode.HORIZONTAL) {
              [hPadding, vPadding] = [vPadding, hPadding];
            }
            const pageWidthScale = (this.container.clientWidth - hPadding) / currentPage.width * currentPage.scale / this._pageWidthScaleFactor;
            const pageHeightScale = (this.container.clientHeight - vPadding) / currentPage.height * currentPage.scale;
            switch (value) {
              case "page-actual":
                scale = 1;
                break;
              case "page-width":
                scale = pageWidthScale;
                break;
              case "page-height":
                scale = pageHeightScale;
                break;
              case "page-fit":
                scale = Math.min(pageWidthScale, pageHeightScale);
                break;
              case "auto":
                const horizontalScale = (0, _ui_utils.isPortraitOrientation)(currentPage) ? pageWidthScale : Math.min(pageHeightScale, pageWidthScale);
                scale = Math.min(_ui_utils.MAX_AUTO_SCALE, horizontalScale);
                break;
              default:
                console.error(`_setScale: "${value}" is an unknown zoom value.`);
                return;
            }
            this._setScaleUpdatePages(scale, value, noScroll, true);
          }
        }
        pageLabelToPageNumber(label) {
          if (!this._pageLabels) {
            return null;
          }
          const i = this._pageLabels.indexOf(label);
          if (i < 0) {
            return null;
          }
          return i + 1;
        }
        scrollPageIntoView({
          pageNumber,
          destArray = null,
          allowNegativeOffset = false,
          ignoreDestinationZoom = false
        }) {
          if (!this.pdfDocument) {
            return;
          }
          const pageView = Number.isInteger(pageNumber) && this._pages[pageNumber - 1];
          if (!pageView) {
            console.error(`scrollPageIntoView: "${pageNumber}" is not a valid pageNumber parameter.`);
            return;
          }
          if (this.isInPresentationMode || !destArray) {
            this._setCurrentPageNumber(pageNumber, true);
            return;
          }
          let x = 0, y = 0;
          let width = 0, height = 0, widthScale, heightScale;
          const changeOrientation = pageView.rotation % 180 !== 0;
          const pageWidth = (changeOrientation ? pageView.height : pageView.width) / pageView.scale / _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS;
          const pageHeight = (changeOrientation ? pageView.width : pageView.height) / pageView.scale / _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS;
          let scale = 0;
          switch (destArray[1].name) {
            case "XYZ":
              x = destArray[2];
              y = destArray[3];
              scale = destArray[4];
              x = x !== null ? x : 0;
              y = y !== null ? y : pageHeight;
              break;
            case "Fit":
            case "FitB":
              scale = "page-fit";
              break;
            case "FitH":
            case "FitBH":
              y = destArray[2];
              scale = "page-width";
              if (y === null && this._location) {
                x = this._location.left;
                y = this._location.top;
              } else if (typeof y !== "number" || y < 0) {
                y = pageHeight;
              }
              break;
            case "FitV":
            case "FitBV":
              x = destArray[2];
              width = pageWidth;
              height = pageHeight;
              scale = "page-height";
              break;
            case "FitR":
              x = destArray[2];
              y = destArray[3];
              width = destArray[4] - x;
              height = destArray[5] - y;
              const hPadding = this.removePageBorders ? 0 : _ui_utils.SCROLLBAR_PADDING;
              const vPadding = this.removePageBorders ? 0 : _ui_utils.VERTICAL_PADDING;
              widthScale = (this.container.clientWidth - hPadding) / width / _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS;
              heightScale = (this.container.clientHeight - vPadding) / height / _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS;
              scale = Math.min(Math.abs(widthScale), Math.abs(heightScale));
              break;
            default:
              console.error(`scrollPageIntoView: "${destArray[1].name}" is not a valid destination type.`);
              return;
          }
          if (!ignoreDestinationZoom) {
            if (scale && scale !== this._currentScale) {
              this.currentScaleValue = scale;
            } else if (this._currentScale === _ui_utils.UNKNOWN_SCALE) {
              this.currentScaleValue = _ui_utils.DEFAULT_SCALE_VALUE;
            }
          }
          if (scale === "page-fit" && !destArray[4]) {
            __privateMethod(this, _BaseViewer_instances, scrollIntoView_fn).call(this, pageView);
            return;
          }
          const boundingRect = [pageView.viewport.convertToViewportPoint(x, y), pageView.viewport.convertToViewportPoint(x + width, y + height)];
          let left = Math.min(boundingRect[0][0], boundingRect[1][0]);
          let top = Math.min(boundingRect[0][1], boundingRect[1][1]);
          if (!allowNegativeOffset) {
            left = Math.max(left, 0);
            top = Math.max(top, 0);
          }
          __privateMethod(this, _BaseViewer_instances, scrollIntoView_fn).call(this, pageView, {
            left,
            top
          });
        }
        _updateLocation(firstPage) {
          const currentScale = this._currentScale;
          const currentScaleValue = this._currentScaleValue;
          const normalizedScaleValue = parseFloat(currentScaleValue) === currentScale ? Math.round(currentScale * 1e4) / 100 : currentScaleValue;
          const pageNumber = firstPage.id;
          const currentPageView = this._pages[pageNumber - 1];
          const container = this.container;
          const topLeft = currentPageView.getPagePoint(container.scrollLeft - firstPage.x, container.scrollTop - firstPage.y);
          const intLeft = Math.round(topLeft[0]);
          const intTop = Math.round(topLeft[1]);
          let pdfOpenParams = `#page=${pageNumber}`;
          if (!this.isInPresentationMode) {
            pdfOpenParams += `&zoom=${normalizedScaleValue},${intLeft},${intTop}`;
          }
          this._location = {
            pageNumber,
            scale: normalizedScaleValue,
            top: intTop,
            left: intLeft,
            rotation: this._pagesRotation,
            pdfOpenParams
          };
        }
        update() {
          const visible = this._getVisiblePages();
          const visiblePages = visible.views, numVisiblePages = visiblePages.length;
          if (numVisiblePages === 0) {
            return;
          }
          const newCacheSize = Math.max(DEFAULT_CACHE_SIZE, 2 * numVisiblePages + 1);
          __privateGet(this, _buffer).resize(newCacheSize, visible.ids);
          this.renderingQueue.renderHighestPriority(visible);
          const isSimpleLayout = this._spreadMode === _ui_utils.SpreadMode.NONE && (this._scrollMode === _ui_utils.ScrollMode.PAGE || this._scrollMode === _ui_utils.ScrollMode.VERTICAL);
          const currentId = this._currentPageNumber;
          let stillFullyVisible = false;
          for (const page of visiblePages) {
            if (page.percent < 100) {
              break;
            }
            if (page.id === currentId && isSimpleLayout) {
              stillFullyVisible = true;
              break;
            }
          }
          this._setCurrentPageNumber(stillFullyVisible ? currentId : visiblePages[0].id);
          this._updateLocation(visible.first);
          this.eventBus.dispatch("updateviewarea", {
            source: this,
            location: this._location
          });
        }
        containsElement(element) {
          return this.container.contains(element);
        }
        focus() {
          this.container.focus();
        }
        get _isContainerRtl() {
          return getComputedStyle(this.container).direction === "rtl";
        }
        get isInPresentationMode() {
          return this.presentationModeState === _ui_utils.PresentationModeState.FULLSCREEN;
        }
        get isChangingPresentationMode() {
          return this.presentationModeState === _ui_utils.PresentationModeState.CHANGING;
        }
        get isHorizontalScrollbarEnabled() {
          return this.isInPresentationMode ? false : this.container.scrollWidth > this.container.clientWidth;
        }
        get isVerticalScrollbarEnabled() {
          return this.isInPresentationMode ? false : this.container.scrollHeight > this.container.clientHeight;
        }
        _getVisiblePages() {
          const views = this._scrollMode === _ui_utils.ScrollMode.PAGE ? __privateGet(this, _scrollModePageState).pages : this._pages, horizontal = this._scrollMode === _ui_utils.ScrollMode.HORIZONTAL, rtl = horizontal && this._isContainerRtl;
          return (0, _ui_utils.getVisibleElements)({
            scrollEl: this.container,
            views,
            sortByVisibility: true,
            horizontal,
            rtl
          });
        }
        isPageVisible(pageNumber) {
          if (!this.pdfDocument) {
            return false;
          }
          if (!(Number.isInteger(pageNumber) && pageNumber > 0 && pageNumber <= this.pagesCount)) {
            console.error(`isPageVisible: "${pageNumber}" is not a valid page.`);
            return false;
          }
          return this._getVisiblePages().ids.has(pageNumber);
        }
        isPageCached(pageNumber) {
          if (!this.pdfDocument) {
            return false;
          }
          if (!(Number.isInteger(pageNumber) && pageNumber > 0 && pageNumber <= this.pagesCount)) {
            console.error(`isPageCached: "${pageNumber}" is not a valid page.`);
            return false;
          }
          const pageView = this._pages[pageNumber - 1];
          return __privateGet(this, _buffer).has(pageView);
        }
        cleanup() {
          for (const pageView of this._pages) {
            if (pageView.renderingState !== _ui_utils.RenderingStates.FINISHED) {
              pageView.reset();
            }
          }
        }
        _cancelRendering() {
          for (const pageView of this._pages) {
            pageView.cancelRendering();
          }
        }
        forceRendering(currentlyVisiblePages) {
          const visiblePages = currentlyVisiblePages || this._getVisiblePages();
          const scrollAhead = __privateMethod(this, _BaseViewer_instances, getScrollAhead_fn).call(this, visiblePages);
          const preRenderExtra = this._spreadMode !== _ui_utils.SpreadMode.NONE && this._scrollMode !== _ui_utils.ScrollMode.HORIZONTAL;
          const pageView = this.renderingQueue.getHighestPriority(visiblePages, this._pages, scrollAhead, preRenderExtra);
          __privateMethod(this, _BaseViewer_instances, toggleLoadingIconSpinner_fn).call(this, visiblePages.ids);
          if (pageView) {
            __privateMethod(this, _BaseViewer_instances, ensurePdfPageLoaded_fn).call(this, pageView).then(() => {
              this.renderingQueue.renderView(pageView);
            });
            return true;
          }
          return false;
        }
        createTextLayerBuilder({
          textLayerDiv,
          pageIndex,
          viewport,
          enhanceTextSelection = false,
          eventBus,
          highlighter,
          accessibilityManager = null
        }) {
          return new _text_layer_builder.TextLayerBuilder({
            textLayerDiv,
            eventBus,
            pageIndex,
            viewport,
            enhanceTextSelection: this.isInPresentationMode ? false : enhanceTextSelection,
            highlighter,
            accessibilityManager
          });
        }
        createTextHighlighter({
          pageIndex,
          eventBus
        }) {
          return new _text_highlighter.TextHighlighter({
            eventBus,
            pageIndex,
            findController: this.isInPresentationMode ? null : this.findController
          });
        }
        createAnnotationLayerBuilder({
          pageDiv,
          pdfPage,
          annotationStorage = ((_a) => (_a = this.pdfDocument) == null ? void 0 : _a.annotationStorage)(),
          imageResourcesPath = "",
          renderForms = true,
          l10n = _l10n_utils.NullL10n,
          enableScripting = this.enableScripting,
          hasJSActionsPromise = ((_b) => (_b = this.pdfDocument) == null ? void 0 : _b.hasJSActions())(),
          mouseState = ((_c) => (_c = this._scriptingManager) == null ? void 0 : _c.mouseState)(),
          fieldObjectsPromise = ((_d) => (_d = this.pdfDocument) == null ? void 0 : _d.getFieldObjects())(),
          annotationCanvasMap = null,
          accessibilityManager = null
        }) {
          return new _annotation_layer_builder.AnnotationLayerBuilder({
            pageDiv,
            pdfPage,
            annotationStorage,
            imageResourcesPath,
            renderForms,
            linkService: this.linkService,
            downloadManager: this.downloadManager,
            l10n,
            enableScripting,
            hasJSActionsPromise,
            mouseState,
            fieldObjectsPromise,
            annotationCanvasMap,
            accessibilityManager
          });
        }
        createAnnotationEditorLayerBuilder({
          uiManager = __privateGet(this, _annotationEditorUIManager),
          pageDiv,
          pdfPage,
          accessibilityManager = null,
          l10n,
          annotationStorage = ((_e) => (_e = this.pdfDocument) == null ? void 0 : _e.annotationStorage)()
        }) {
          return new _annotation_editor_layer_builder.AnnotationEditorLayerBuilder({
            uiManager,
            pageDiv,
            pdfPage,
            annotationStorage,
            accessibilityManager,
            l10n
          });
        }
        createXfaLayerBuilder({
          pageDiv,
          pdfPage,
          annotationStorage = ((_f) => (_f = this.pdfDocument) == null ? void 0 : _f.annotationStorage)()
        }) {
          return new _xfa_layer_builder.XfaLayerBuilder({
            pageDiv,
            pdfPage,
            annotationStorage,
            linkService: this.linkService
          });
        }
        createStructTreeLayerBuilder({
          pdfPage
        }) {
          return new _struct_tree_layer_builder.StructTreeLayerBuilder({
            pdfPage
          });
        }
        get hasEqualPageSizes() {
          const firstPageView = this._pages[0];
          for (let i = 1, ii = this._pages.length; i < ii; ++i) {
            const pageView = this._pages[i];
            if (pageView.width !== firstPageView.width || pageView.height !== firstPageView.height) {
              return false;
            }
          }
          return true;
        }
        getPagesOverview() {
          return this._pages.map((pageView) => {
            const viewport = pageView.pdfPage.getViewport({
              scale: 1
            });
            if (!this.enablePrintAutoRotate || (0, _ui_utils.isPortraitOrientation)(viewport)) {
              return {
                width: viewport.width,
                height: viewport.height,
                rotation: viewport.rotation
              };
            }
            return {
              width: viewport.height,
              height: viewport.width,
              rotation: (viewport.rotation - 90) % 360
            };
          });
        }
        get optionalContentConfigPromise() {
          if (!this.pdfDocument) {
            return Promise.resolve(null);
          }
          if (!this._optionalContentConfigPromise) {
            console.error("optionalContentConfigPromise: Not initialized yet.");
            return this.pdfDocument.getOptionalContentConfig();
          }
          return this._optionalContentConfigPromise;
        }
        set optionalContentConfigPromise(promise) {
          if (!(promise instanceof Promise)) {
            throw new Error(`Invalid optionalContentConfigPromise: ${promise}`);
          }
          if (!this.pdfDocument) {
            return;
          }
          if (!this._optionalContentConfigPromise) {
            return;
          }
          this._optionalContentConfigPromise = promise;
          const updateArgs = {
            optionalContentConfigPromise: promise
          };
          for (const pageView of this._pages) {
            pageView.update(updateArgs);
          }
          this.update();
          this.eventBus.dispatch("optionalcontentconfigchanged", {
            source: this,
            promise
          });
        }
        get scrollMode() {
          return this._scrollMode;
        }
        set scrollMode(mode) {
          if (this._scrollMode === mode) {
            return;
          }
          if (!(0, _ui_utils.isValidScrollMode)(mode)) {
            throw new Error(`Invalid scroll mode: ${mode}`);
          }
          if (this.pagesCount > PagesCountLimit.FORCE_SCROLL_MODE_PAGE) {
            return;
          }
          this._previousScrollMode = this._scrollMode;
          this._scrollMode = mode;
          this.eventBus.dispatch("scrollmodechanged", {
            source: this,
            mode
          });
          this._updateScrollMode(this._currentPageNumber);
        }
        _updateScrollMode(pageNumber = null) {
          const scrollMode = this._scrollMode, viewer = this.viewer;
          viewer.classList.toggle("scrollHorizontal", scrollMode === _ui_utils.ScrollMode.HORIZONTAL);
          viewer.classList.toggle("scrollWrapped", scrollMode === _ui_utils.ScrollMode.WRAPPED);
          if (!this.pdfDocument || !pageNumber) {
            return;
          }
          if (scrollMode === _ui_utils.ScrollMode.PAGE) {
            __privateMethod(this, _BaseViewer_instances, ensurePageViewVisible_fn).call(this);
          } else if (this._previousScrollMode === _ui_utils.ScrollMode.PAGE) {
            this._updateSpreadMode();
          }
          if (this._currentScaleValue && isNaN(this._currentScaleValue)) {
            this._setScale(this._currentScaleValue, true);
          }
          this._setCurrentPageNumber(pageNumber, true);
          this.update();
        }
        get spreadMode() {
          return this._spreadMode;
        }
        set spreadMode(mode) {
          if (this._spreadMode === mode) {
            return;
          }
          if (!(0, _ui_utils.isValidSpreadMode)(mode)) {
            throw new Error(`Invalid spread mode: ${mode}`);
          }
          this._spreadMode = mode;
          this.eventBus.dispatch("spreadmodechanged", {
            source: this,
            mode
          });
          this._updateSpreadMode(this._currentPageNumber);
        }
        _updateSpreadMode(pageNumber = null) {
          if (!this.pdfDocument) {
            return;
          }
          const viewer = this.viewer, pages = this._pages;
          if (this._scrollMode === _ui_utils.ScrollMode.PAGE) {
            __privateMethod(this, _BaseViewer_instances, ensurePageViewVisible_fn).call(this);
          } else {
            viewer.textContent = "";
            if (this._spreadMode === _ui_utils.SpreadMode.NONE) {
              for (const pageView of this._pages) {
                viewer.append(pageView.div);
              }
            } else {
              const parity = this._spreadMode - 1;
              let spread = null;
              for (let i = 0, ii = pages.length; i < ii; ++i) {
                if (spread === null) {
                  spread = document.createElement("div");
                  spread.className = "spread";
                  viewer.append(spread);
                } else if (i % 2 === parity) {
                  spread = spread.cloneNode(false);
                  viewer.append(spread);
                }
                spread.append(pages[i].div);
              }
            }
          }
          if (!pageNumber) {
            return;
          }
          if (this._currentScaleValue && isNaN(this._currentScaleValue)) {
            this._setScale(this._currentScaleValue, true);
          }
          this._setCurrentPageNumber(pageNumber, true);
          this.update();
        }
        _getPageAdvance(currentPageNumber, previous = false) {
          switch (this._scrollMode) {
            case _ui_utils.ScrollMode.WRAPPED: {
              const {
                views
              } = this._getVisiblePages(), pageLayout = /* @__PURE__ */ new Map();
              for (const {
                id,
                y,
                percent,
                widthPercent
              } of views) {
                if (percent === 0 || widthPercent < 100) {
                  continue;
                }
                let yArray = pageLayout.get(y);
                if (!yArray) {
                  pageLayout.set(y, yArray || (yArray = []));
                }
                yArray.push(id);
              }
              for (const yArray of pageLayout.values()) {
                const currentIndex = yArray.indexOf(currentPageNumber);
                if (currentIndex === -1) {
                  continue;
                }
                const numPages = yArray.length;
                if (numPages === 1) {
                  break;
                }
                if (previous) {
                  for (let i = currentIndex - 1, ii = 0; i >= ii; i--) {
                    const currentId = yArray[i], expectedId = yArray[i + 1] - 1;
                    if (currentId < expectedId) {
                      return currentPageNumber - expectedId;
                    }
                  }
                } else {
                  for (let i = currentIndex + 1, ii = numPages; i < ii; i++) {
                    const currentId = yArray[i], expectedId = yArray[i - 1] + 1;
                    if (currentId > expectedId) {
                      return expectedId - currentPageNumber;
                    }
                  }
                }
                if (previous) {
                  const firstId = yArray[0];
                  if (firstId < currentPageNumber) {
                    return currentPageNumber - firstId + 1;
                  }
                } else {
                  const lastId = yArray[numPages - 1];
                  if (lastId > currentPageNumber) {
                    return lastId - currentPageNumber + 1;
                  }
                }
                break;
              }
              break;
            }
            case _ui_utils.ScrollMode.HORIZONTAL: {
              break;
            }
            case _ui_utils.ScrollMode.PAGE:
            case _ui_utils.ScrollMode.VERTICAL: {
              if (this._spreadMode === _ui_utils.SpreadMode.NONE) {
                break;
              }
              const parity = this._spreadMode - 1;
              if (previous && currentPageNumber % 2 !== parity) {
                break;
              } else if (!previous && currentPageNumber % 2 === parity) {
                break;
              }
              const {
                views
              } = this._getVisiblePages(), expectedId = previous ? currentPageNumber - 1 : currentPageNumber + 1;
              for (const {
                id,
                percent,
                widthPercent
              } of views) {
                if (id !== expectedId) {
                  continue;
                }
                if (percent > 0 && widthPercent === 100) {
                  return 2;
                }
                break;
              }
              break;
            }
          }
          return 1;
        }
        nextPage() {
          const currentPageNumber = this._currentPageNumber, pagesCount = this.pagesCount;
          if (currentPageNumber >= pagesCount) {
            return false;
          }
          const advance = this._getPageAdvance(currentPageNumber, false) || 1;
          this.currentPageNumber = Math.min(currentPageNumber + advance, pagesCount);
          return true;
        }
        previousPage() {
          const currentPageNumber = this._currentPageNumber;
          if (currentPageNumber <= 1) {
            return false;
          }
          const advance = this._getPageAdvance(currentPageNumber, true) || 1;
          this.currentPageNumber = Math.max(currentPageNumber - advance, 1);
          return true;
        }
        increaseScale(steps = 1) {
          let newScale = this._currentScale;
          do {
            newScale = (newScale * _ui_utils.DEFAULT_SCALE_DELTA).toFixed(2);
            newScale = Math.ceil(newScale * 10) / 10;
            newScale = Math.min(_ui_utils.MAX_SCALE, newScale);
          } while (--steps > 0 && newScale < _ui_utils.MAX_SCALE);
          this.currentScaleValue = newScale;
        }
        decreaseScale(steps = 1) {
          let newScale = this._currentScale;
          do {
            newScale = (newScale / _ui_utils.DEFAULT_SCALE_DELTA).toFixed(2);
            newScale = Math.floor(newScale * 10) / 10;
            newScale = Math.max(_ui_utils.MIN_SCALE, newScale);
          } while (--steps > 0 && newScale > _ui_utils.MIN_SCALE);
          this.currentScaleValue = newScale;
        }
        updateContainerHeightCss() {
          const height = this.container.clientHeight;
          if (height !== __privateGet(this, _previousContainerHeight)) {
            __privateSet(this, _previousContainerHeight, height);
            _ui_utils.docStyle.setProperty("--viewer-container-height", `${height}px`);
          }
        }
        get annotationEditorMode() {
          return __privateGet(this, _annotationEditorUIManager) ? __privateGet(this, _annotationEditorMode) : _pdfjsLib.AnnotationEditorType.DISABLE;
        }
        set annotationEditorMode(mode) {
          if (!__privateGet(this, _annotationEditorUIManager)) {
            throw new Error(`The AnnotationEditor is not enabled.`);
          }
          if (__privateGet(this, _annotationEditorMode) === mode) {
            return;
          }
          if (!isValidAnnotationEditorMode(mode)) {
            throw new Error(`Invalid AnnotationEditor mode: ${mode}`);
          }
          if (!this.pdfDocument) {
            return;
          }
          __privateSet(this, _annotationEditorMode, mode);
          this.eventBus.dispatch("annotationeditormodechanged", {
            source: this,
            mode
          });
          __privateGet(this, _annotationEditorUIManager).updateMode(mode);
        }
        set annotationEditorParams({
          type,
          value
        }) {
          if (!__privateGet(this, _annotationEditorUIManager)) {
            throw new Error(`The AnnotationEditor is not enabled.`);
          }
          __privateGet(this, _annotationEditorUIManager).updateParams(type, value);
        }
        refresh() {
          if (!this.pdfDocument) {
            return;
          }
          const updateArgs = {};
          for (const pageView of this._pages) {
            pageView.update(updateArgs);
          }
          this.update();
        }
      };
      _buffer = new WeakMap();
      _annotationEditorMode = new WeakMap();
      _annotationEditorUIManager = new WeakMap();
      _annotationMode = new WeakMap();
      _enablePermissions = new WeakMap();
      _previousContainerHeight = new WeakMap();
      _scrollModePageState = new WeakMap();
      _onVisibilityChange = new WeakMap();
      _BaseViewer_instances = new WeakSet();
      initializePermissions_fn = function(permissions) {
        const params = {
          annotationEditorMode: __privateGet(this, _annotationEditorMode),
          annotationMode: __privateGet(this, _annotationMode),
          textLayerMode: this.textLayerMode
        };
        if (!permissions) {
          return params;
        }
        if (!permissions.includes(_pdfjsLib.PermissionFlag.COPY)) {
          this.viewer.classList.add(ENABLE_PERMISSIONS_CLASS);
        }
        if (!permissions.includes(_pdfjsLib.PermissionFlag.MODIFY_CONTENTS)) {
          params.annotationEditorMode = _pdfjsLib.AnnotationEditorType.DISABLE;
        }
        if (!permissions.includes(_pdfjsLib.PermissionFlag.MODIFY_ANNOTATIONS) && !permissions.includes(_pdfjsLib.PermissionFlag.FILL_INTERACTIVE_FORMS) && __privateGet(this, _annotationMode) === _pdfjsLib.AnnotationMode.ENABLE_FORMS) {
          params.annotationMode = _pdfjsLib.AnnotationMode.ENABLE;
        }
        return params;
      };
      onePageRenderedOrForceFetch_fn = function() {
        if (document.visibilityState === "hidden" || !this.container.offsetParent || this._getVisiblePages().views.length === 0) {
          return Promise.resolve();
        }
        const visibilityChangePromise = new Promise((resolve) => {
          __privateSet(this, _onVisibilityChange, () => {
            if (document.visibilityState !== "hidden") {
              return;
            }
            resolve();
            document.removeEventListener("visibilitychange", __privateGet(this, _onVisibilityChange));
            __privateSet(this, _onVisibilityChange, null);
          });
          document.addEventListener("visibilitychange", __privateGet(this, _onVisibilityChange));
        });
        return Promise.race([this._onePageRenderedCapability.promise, visibilityChangePromise]);
      };
      ensurePageViewVisible_fn = function() {
        if (this._scrollMode !== _ui_utils.ScrollMode.PAGE) {
          throw new Error("#ensurePageViewVisible: Invalid scrollMode value.");
        }
        const pageNumber = this._currentPageNumber, state = __privateGet(this, _scrollModePageState), viewer = this.viewer;
        viewer.textContent = "";
        state.pages.length = 0;
        if (this._spreadMode === _ui_utils.SpreadMode.NONE && !this.isInPresentationMode) {
          const pageView = this._pages[pageNumber - 1];
          viewer.append(pageView.div);
          state.pages.push(pageView);
        } else {
          const pageIndexSet = /* @__PURE__ */ new Set(), parity = this._spreadMode - 1;
          if (parity === -1) {
            pageIndexSet.add(pageNumber - 1);
          } else if (pageNumber % 2 !== parity) {
            pageIndexSet.add(pageNumber - 1);
            pageIndexSet.add(pageNumber);
          } else {
            pageIndexSet.add(pageNumber - 2);
            pageIndexSet.add(pageNumber - 1);
          }
          const spread = document.createElement("div");
          spread.className = "spread";
          if (this.isInPresentationMode) {
            const dummyPage = document.createElement("div");
            dummyPage.className = "dummyPage";
            spread.append(dummyPage);
          }
          for (const i of pageIndexSet) {
            const pageView = this._pages[i];
            if (!pageView) {
              continue;
            }
            spread.append(pageView.div);
            state.pages.push(pageView);
          }
          viewer.append(spread);
        }
        state.scrollDown = pageNumber >= state.previousPageNumber;
        state.previousPageNumber = pageNumber;
      };
      scrollIntoView_fn = function(pageView, pageSpot = null) {
        const {
          div,
          id
        } = pageView;
        if (this._scrollMode === _ui_utils.ScrollMode.PAGE) {
          this._setCurrentPageNumber(id);
          __privateMethod(this, _BaseViewer_instances, ensurePageViewVisible_fn).call(this);
          this.update();
        }
        if (!pageSpot && !this.isInPresentationMode) {
          const left = div.offsetLeft + div.clientLeft, right = left + div.clientWidth;
          const {
            scrollLeft,
            clientWidth
          } = this.container;
          if (this._scrollMode === _ui_utils.ScrollMode.HORIZONTAL || left < scrollLeft || right > scrollLeft + clientWidth) {
            pageSpot = {
              left: 0,
              top: 0
            };
          }
        }
        (0, _ui_utils.scrollIntoView)(div, pageSpot);
      };
      isSameScale_fn = function(newScale) {
        return newScale === this._currentScale || Math.abs(newScale - this._currentScale) < 1e-15;
      };
      resetCurrentPageView_fn = function() {
        const pageView = this._pages[this._currentPageNumber - 1];
        if (this.isInPresentationMode) {
          this._setScale(this._currentScaleValue, true);
        }
        __privateMethod(this, _BaseViewer_instances, scrollIntoView_fn).call(this, pageView);
      };
      ensurePdfPageLoaded_fn = async function(pageView) {
        var _a, _b;
        if (pageView.pdfPage) {
          return pageView.pdfPage;
        }
        try {
          const pdfPage = await this.pdfDocument.getPage(pageView.id);
          if (!pageView.pdfPage) {
            pageView.setPdfPage(pdfPage);
          }
          if (!((_b = (_a = this.linkService)._cachedPageNumber) == null ? void 0 : _b.call(_a, pdfPage.ref))) {
            this.linkService.cachePageRef(pageView.id, pdfPage.ref);
          }
          return pdfPage;
        } catch (reason) {
          console.error("Unable to get page for page view", reason);
          return null;
        }
      };
      getScrollAhead_fn = function(visible) {
        var _a, _b;
        if (((_a = visible.first) == null ? void 0 : _a.id) === 1) {
          return true;
        } else if (((_b = visible.last) == null ? void 0 : _b.id) === this.pagesCount) {
          return false;
        }
        switch (this._scrollMode) {
          case _ui_utils.ScrollMode.PAGE:
            return __privateGet(this, _scrollModePageState).scrollDown;
          case _ui_utils.ScrollMode.HORIZONTAL:
            return this.scroll.right;
        }
        return this.scroll.down;
      };
      toggleLoadingIconSpinner_fn = function(visibleIds) {
        for (const id of visibleIds) {
          const pageView = this._pages[id - 1];
          pageView == null ? void 0 : pageView.toggleLoadingIconSpinner(true);
        }
        for (const pageView of __privateGet(this, _buffer)) {
          if (visibleIds.has(pageView.id)) {
            continue;
          }
          pageView.toggleLoadingIconSpinner(false);
        }
      };
      let BaseViewer = _BaseViewer;
      exports.BaseViewer = BaseViewer;
    }),
    /* 30 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _uiManager;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.AnnotationEditorLayerBuilder = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      var _l10n_utils = __webpack_require__2(31);
      class AnnotationEditorLayerBuilder {
        constructor(options) {
          __privateAdd(this, _uiManager);
          this.pageDiv = options.pageDiv;
          this.pdfPage = options.pdfPage;
          this.annotationStorage = options.annotationStorage || null;
          this.accessibilityManager = options.accessibilityManager;
          this.l10n = options.l10n || _l10n_utils.NullL10n;
          this.annotationEditorLayer = null;
          this.div = null;
          this._cancelled = false;
          __privateSet(this, _uiManager, options.uiManager);
        }
        async render(viewport, intent = "display") {
          if (intent !== "display") {
            return;
          }
          if (this._cancelled) {
            return;
          }
          const clonedViewport = viewport.clone({
            dontFlip: true
          });
          if (this.div) {
            this.annotationEditorLayer.update({
              viewport: clonedViewport
            });
            this.show();
            return;
          }
          this.div = document.createElement("div");
          this.div.className = "annotationEditorLayer";
          this.div.tabIndex = 0;
          this.pageDiv.append(this.div);
          this.annotationEditorLayer = new _pdfjsLib.AnnotationEditorLayer({
            uiManager: __privateGet(this, _uiManager),
            div: this.div,
            annotationStorage: this.annotationStorage,
            accessibilityManager: this.accessibilityManager,
            pageIndex: this.pdfPage._pageIndex,
            l10n: this.l10n,
            viewport: clonedViewport
          });
          const parameters = {
            viewport: clonedViewport,
            div: this.div,
            annotations: null,
            intent
          };
          this.annotationEditorLayer.render(parameters);
        }
        cancel() {
          this._cancelled = true;
          this.destroy();
        }
        hide() {
          if (!this.div) {
            return;
          }
          this.div.hidden = true;
        }
        show() {
          if (!this.div) {
            return;
          }
          this.div.hidden = false;
        }
        destroy() {
          if (!this.div) {
            return;
          }
          this.pageDiv = null;
          this.annotationEditorLayer.destroy();
          this.div.remove();
        }
      }
      _uiManager = new WeakMap();
      exports.AnnotationEditorLayerBuilder = AnnotationEditorLayerBuilder;
    }),
    /* 31 */
    /***/
    ((__unused_webpack_module, exports) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.NullL10n = void 0;
      exports.fixupLangCode = fixupLangCode;
      exports.getL10nFallback = getL10nFallback;
      const DEFAULT_L10N_STRINGS = {
        of_pages: "of {{pagesCount}}",
        page_of_pages: "({{pageNumber}} of {{pagesCount}})",
        document_properties_kb: "{{size_kb}} KB ({{size_b}} bytes)",
        document_properties_mb: "{{size_mb}} MB ({{size_b}} bytes)",
        document_properties_date_string: "{{date}}, {{time}}",
        document_properties_page_size_unit_inches: "in",
        document_properties_page_size_unit_millimeters: "mm",
        document_properties_page_size_orientation_portrait: "portrait",
        document_properties_page_size_orientation_landscape: "landscape",
        document_properties_page_size_name_a3: "A3",
        document_properties_page_size_name_a4: "A4",
        document_properties_page_size_name_letter: "Letter",
        document_properties_page_size_name_legal: "Legal",
        document_properties_page_size_dimension_string: "{{width}} \xD7 {{height}} {{unit}} ({{orientation}})",
        document_properties_page_size_dimension_name_string: "{{width}} \xD7 {{height}} {{unit}} ({{name}}, {{orientation}})",
        document_properties_linearized_yes: "Yes",
        document_properties_linearized_no: "No",
        print_progress_percent: "{{progress}}%",
        "toggle_sidebar.title": "Toggle Sidebar",
        "toggle_sidebar_notification2.title": "Toggle Sidebar (document contains outline/attachments/layers)",
        additional_layers: "Additional Layers",
        page_landmark: "Page {{page}}",
        thumb_page_title: "Page {{page}}",
        thumb_page_canvas: "Thumbnail of Page {{page}}",
        find_reached_top: "Reached top of document, continued from bottom",
        find_reached_bottom: "Reached end of document, continued from top",
        "find_match_count[one]": "{{current}} of {{total}} match",
        "find_match_count[other]": "{{current}} of {{total}} matches",
        "find_match_count_limit[one]": "More than {{limit}} match",
        "find_match_count_limit[other]": "More than {{limit}} matches",
        find_not_found: "Phrase not found",
        error_version_info: "PDF.js v{{version}} (build: {{build}})",
        error_message: "Message: {{message}}",
        error_stack: "Stack: {{stack}}",
        error_file: "File: {{file}}",
        error_line: "Line: {{line}}",
        rendering_error: "An error occurred while rendering the page.",
        page_scale_width: "Page Width",
        page_scale_fit: "Page Fit",
        page_scale_auto: "Automatic Zoom",
        page_scale_actual: "Actual Size",
        page_scale_percent: "{{scale}}%",
        loading: "Loading\u2026",
        loading_error: "An error occurred while loading the PDF.",
        invalid_file_error: "Invalid or corrupted PDF file.",
        missing_file_error: "Missing PDF file.",
        unexpected_response_error: "Unexpected server response.",
        printing_not_supported: "Warning: Printing is not fully supported by this browser.",
        printing_not_ready: "Warning: The PDF is not fully loaded for printing.",
        web_fonts_disabled: "Web fonts are disabled: unable to use embedded PDF fonts.",
        free_text_default_content: "Enter text\u2026",
        editor_free_text_aria_label: "FreeText Editor",
        editor_ink_aria_label: "Ink Editor",
        editor_ink_canvas_aria_label: "User-created image"
      };
      function getL10nFallback(key, args) {
        switch (key) {
          case "find_match_count":
            key = `find_match_count[${args.total === 1 ? "one" : "other"}]`;
            break;
          case "find_match_count_limit":
            key = `find_match_count_limit[${args.limit === 1 ? "one" : "other"}]`;
            break;
        }
        return DEFAULT_L10N_STRINGS[key] || "";
      }
      const PARTIAL_LANG_CODES = {
        en: "en-US",
        es: "es-ES",
        fy: "fy-NL",
        ga: "ga-IE",
        gu: "gu-IN",
        hi: "hi-IN",
        hy: "hy-AM",
        nb: "nb-NO",
        ne: "ne-NP",
        nn: "nn-NO",
        pa: "pa-IN",
        pt: "pt-PT",
        sv: "sv-SE",
        zh: "zh-CN"
      };
      function fixupLangCode(langCode) {
        return PARTIAL_LANG_CODES[langCode == null ? void 0 : langCode.toLowerCase()] || langCode;
      }
      function formatL10nValue(text, args) {
        if (!args) {
          return text;
        }
        return text.replace(/\{\{\s*(\w+)\s*\}\}/g, (all, name) => {
          return name in args ? args[name] : "{{" + name + "}}";
        });
      }
      const NullL10n = {
        async getLanguage() {
          return "en-us";
        },
        async getDirection() {
          return "ltr";
        },
        async get(key, args = null, fallback = getL10nFallback(key, args)) {
          return formatL10nValue(fallback, args);
        },
        async translate(element) {
        }
      };
      exports.NullL10n = NullL10n;
    }),
    /* 32 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.AnnotationLayerBuilder = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      var _l10n_utils = __webpack_require__2(31);
      class AnnotationLayerBuilder {
        constructor({
          pageDiv,
          pdfPage,
          linkService,
          downloadManager,
          annotationStorage = null,
          imageResourcesPath = "",
          renderForms = true,
          l10n = _l10n_utils.NullL10n,
          enableScripting = false,
          hasJSActionsPromise = null,
          fieldObjectsPromise = null,
          mouseState = null,
          annotationCanvasMap = null,
          accessibilityManager = null
        }) {
          this.pageDiv = pageDiv;
          this.pdfPage = pdfPage;
          this.linkService = linkService;
          this.downloadManager = downloadManager;
          this.imageResourcesPath = imageResourcesPath;
          this.renderForms = renderForms;
          this.l10n = l10n;
          this.annotationStorage = annotationStorage;
          this.enableScripting = enableScripting;
          this._hasJSActionsPromise = hasJSActionsPromise;
          this._fieldObjectsPromise = fieldObjectsPromise;
          this._mouseState = mouseState;
          this._annotationCanvasMap = annotationCanvasMap;
          this._accessibilityManager = accessibilityManager;
          this.div = null;
          this._cancelled = false;
        }
        async render(viewport, intent = "display") {
          const [annotations, hasJSActions = false, fieldObjects = null] = await Promise.all([this.pdfPage.getAnnotations({
            intent
          }), this._hasJSActionsPromise, this._fieldObjectsPromise]);
          if (this._cancelled || annotations.length === 0) {
            return;
          }
          const parameters = {
            viewport: viewport.clone({
              dontFlip: true
            }),
            div: this.div,
            annotations,
            page: this.pdfPage,
            imageResourcesPath: this.imageResourcesPath,
            renderForms: this.renderForms,
            linkService: this.linkService,
            downloadManager: this.downloadManager,
            annotationStorage: this.annotationStorage,
            enableScripting: this.enableScripting,
            hasJSActions,
            fieldObjects,
            mouseState: this._mouseState,
            annotationCanvasMap: this._annotationCanvasMap,
            accessibilityManager: this._accessibilityManager
          };
          if (this.div) {
            _pdfjsLib.AnnotationLayer.update(parameters);
          } else {
            this.div = document.createElement("div");
            this.div.className = "annotationLayer";
            this.pageDiv.append(this.div);
            parameters.div = this.div;
            _pdfjsLib.AnnotationLayer.render(parameters);
            this.l10n.translate(this.div);
          }
        }
        cancel() {
          this._cancelled = true;
        }
        hide() {
          if (!this.div) {
            return;
          }
          this.div.hidden = true;
        }
      }
      exports.AnnotationLayerBuilder = AnnotationLayerBuilder;
    }),
    /* 33 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _annotationMode, _useThumbnailCanvas;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFPageView = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      var _ui_utils = __webpack_require__2(1);
      var _app_options = __webpack_require__2(2);
      var _l10n_utils = __webpack_require__2(31);
      var _text_accessibility = __webpack_require__2(34);
      const MAX_CANVAS_PIXELS = _app_options.compatibilityParams.maxCanvasPixels || 16777216;
      class PDFPageView {
        constructor(options) {
          __privateAdd(this, _annotationMode, _pdfjsLib.AnnotationMode.ENABLE_FORMS);
          __privateAdd(this, _useThumbnailCanvas, {
            initialOptionalContent: true,
            regularAnnotations: true
          });
          var _a, _b;
          const container = options.container;
          const defaultViewport = options.defaultViewport;
          this.id = options.id;
          this.renderingId = "page" + this.id;
          this.pdfPage = null;
          this.pageLabel = null;
          this.rotation = 0;
          this.scale = options.scale || _ui_utils.DEFAULT_SCALE;
          this.viewport = defaultViewport;
          this.pdfPageRotate = defaultViewport.rotation;
          this._optionalContentConfigPromise = options.optionalContentConfigPromise || null;
          this.hasRestrictedScaling = false;
          this.textLayerMode = options.textLayerMode ?? _ui_utils.TextLayerMode.ENABLE;
          __privateSet(this, _annotationMode, options.annotationMode ?? _pdfjsLib.AnnotationMode.ENABLE_FORMS);
          this.imageResourcesPath = options.imageResourcesPath || "";
          this.useOnlyCssZoom = options.useOnlyCssZoom || false;
          this.maxCanvasPixels = options.maxCanvasPixels || MAX_CANVAS_PIXELS;
          this.pageColors = options.pageColors || null;
          this.eventBus = options.eventBus;
          this.renderingQueue = options.renderingQueue;
          this.textLayerFactory = options.textLayerFactory;
          this.annotationLayerFactory = options.annotationLayerFactory;
          this.annotationEditorLayerFactory = options.annotationEditorLayerFactory;
          this.xfaLayerFactory = options.xfaLayerFactory;
          this.textHighlighter = (_a = options.textHighlighterFactory) == null ? void 0 : _a.createTextHighlighter({
            pageIndex: this.id - 1,
            eventBus: this.eventBus
          });
          this.structTreeLayerFactory = options.structTreeLayerFactory;
          this.renderer = options.renderer || _ui_utils.RendererType.CANVAS;
          this.l10n = options.l10n || _l10n_utils.NullL10n;
          this.paintTask = null;
          this.paintedViewportMap = /* @__PURE__ */ new WeakMap();
          this.renderingState = _ui_utils.RenderingStates.INITIAL;
          this.resume = null;
          this._renderError = null;
          this._isStandalone = !((_b = this.renderingQueue) == null ? void 0 : _b.hasViewer());
          this._annotationCanvasMap = null;
          this.annotationLayer = null;
          this.annotationEditorLayer = null;
          this.textLayer = null;
          this.zoomLayer = null;
          this.xfaLayer = null;
          this.structTreeLayer = null;
          const div = document.createElement("div");
          div.className = "page";
          div.style.width = Math.floor(this.viewport.width) + "px";
          div.style.height = Math.floor(this.viewport.height) + "px";
          div.setAttribute("data-page-number", this.id);
          div.setAttribute("role", "region");
          this.l10n.get("page_landmark", {
            page: this.id
          }).then((msg) => {
            div.setAttribute("aria-label", msg);
          });
          this.div = div;
          container == null ? void 0 : container.append(div);
          if (this._isStandalone) {
            const {
              optionalContentConfigPromise
            } = options;
            if (optionalContentConfigPromise) {
              optionalContentConfigPromise.then((optionalContentConfig) => {
                if (optionalContentConfigPromise !== this._optionalContentConfigPromise) {
                  return;
                }
                __privateGet(this, _useThumbnailCanvas).initialOptionalContent = optionalContentConfig.hasInitialVisibility;
              });
            }
          }
        }
        setPdfPage(pdfPage) {
          this.pdfPage = pdfPage;
          this.pdfPageRotate = pdfPage.rotate;
          const totalRotation = (this.rotation + this.pdfPageRotate) % 360;
          this.viewport = pdfPage.getViewport({
            scale: this.scale * _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS,
            rotation: totalRotation
          });
          this.reset();
        }
        destroy() {
          this.reset();
          if (this.pdfPage) {
            this.pdfPage.cleanup();
          }
        }
        async _renderAnnotationLayer() {
          let error = null;
          try {
            await this.annotationLayer.render(this.viewport, "display");
          } catch (ex) {
            console.error(`_renderAnnotationLayer: "${ex}".`);
            error = ex;
          } finally {
            this.eventBus.dispatch("annotationlayerrendered", {
              source: this,
              pageNumber: this.id,
              error
            });
          }
        }
        async _renderAnnotationEditorLayer() {
          let error = null;
          try {
            await this.annotationEditorLayer.render(this.viewport, "display");
          } catch (ex) {
            console.error(`_renderAnnotationEditorLayer: "${ex}".`);
            error = ex;
          } finally {
            this.eventBus.dispatch("annotationeditorlayerrendered", {
              source: this,
              pageNumber: this.id,
              error
            });
          }
        }
        async _renderXfaLayer() {
          let error = null;
          try {
            const result = await this.xfaLayer.render(this.viewport, "display");
            if (this.textHighlighter) {
              this._buildXfaTextContentItems(result.textDivs);
            }
          } catch (ex) {
            console.error(`_renderXfaLayer: "${ex}".`);
            error = ex;
          } finally {
            this.eventBus.dispatch("xfalayerrendered", {
              source: this,
              pageNumber: this.id,
              error
            });
          }
        }
        async _buildXfaTextContentItems(textDivs) {
          const text = await this.pdfPage.getTextContent();
          const items = [];
          for (const item of text.items) {
            items.push(item.str);
          }
          this.textHighlighter.setTextMapping(textDivs, items);
          this.textHighlighter.enable();
        }
        _resetZoomLayer(removeFromDOM = false) {
          if (!this.zoomLayer) {
            return;
          }
          const zoomLayerCanvas = this.zoomLayer.firstChild;
          this.paintedViewportMap.delete(zoomLayerCanvas);
          zoomLayerCanvas.width = 0;
          zoomLayerCanvas.height = 0;
          if (removeFromDOM) {
            this.zoomLayer.remove();
          }
          this.zoomLayer = null;
        }
        reset({
          keepZoomLayer = false,
          keepAnnotationLayer = false,
          keepAnnotationEditorLayer = false,
          keepXfaLayer = false
        } = {}) {
          var _a, _b, _c, _d;
          this.cancelRendering({
            keepAnnotationLayer,
            keepAnnotationEditorLayer,
            keepXfaLayer
          });
          this.renderingState = _ui_utils.RenderingStates.INITIAL;
          const div = this.div;
          div.style.width = Math.floor(this.viewport.width) + "px";
          div.style.height = Math.floor(this.viewport.height) + "px";
          const childNodes = div.childNodes, zoomLayerNode = keepZoomLayer && this.zoomLayer || null, annotationLayerNode = keepAnnotationLayer && ((_a = this.annotationLayer) == null ? void 0 : _a.div) || null, annotationEditorLayerNode = keepAnnotationEditorLayer && ((_b = this.annotationEditorLayer) == null ? void 0 : _b.div) || null, xfaLayerNode = keepXfaLayer && ((_c = this.xfaLayer) == null ? void 0 : _c.div) || null;
          for (let i = childNodes.length - 1; i >= 0; i--) {
            const node = childNodes[i];
            switch (node) {
              case zoomLayerNode:
              case annotationLayerNode:
              case annotationEditorLayerNode:
              case xfaLayerNode:
                continue;
            }
            node.remove();
          }
          div.removeAttribute("data-loaded");
          if (annotationLayerNode) {
            this.annotationLayer.hide();
          }
          if (annotationEditorLayerNode) {
            this.annotationEditorLayer.hide();
          } else {
            (_d = this.annotationEditorLayer) == null ? void 0 : _d.destroy();
          }
          if (xfaLayerNode) {
            this.xfaLayer.hide();
          }
          if (!zoomLayerNode) {
            if (this.canvas) {
              this.paintedViewportMap.delete(this.canvas);
              this.canvas.width = 0;
              this.canvas.height = 0;
              delete this.canvas;
            }
            this._resetZoomLayer();
          }
          if (this.svg) {
            this.paintedViewportMap.delete(this.svg);
            delete this.svg;
          }
          this.loadingIconDiv = document.createElement("div");
          this.loadingIconDiv.className = "loadingIcon notVisible";
          if (this._isStandalone) {
            this.toggleLoadingIconSpinner(true);
          }
          this.loadingIconDiv.setAttribute("role", "img");
          this.l10n.get("loading").then((msg) => {
            var _a2;
            (_a2 = this.loadingIconDiv) == null ? void 0 : _a2.setAttribute("aria-label", msg);
          });
          div.append(this.loadingIconDiv);
        }
        update({
          scale = 0,
          rotation = null,
          optionalContentConfigPromise = null
        }) {
          this.scale = scale || this.scale;
          if (typeof rotation === "number") {
            this.rotation = rotation;
          }
          if (optionalContentConfigPromise instanceof Promise) {
            this._optionalContentConfigPromise = optionalContentConfigPromise;
            optionalContentConfigPromise.then((optionalContentConfig) => {
              if (optionalContentConfigPromise !== this._optionalContentConfigPromise) {
                return;
              }
              __privateGet(this, _useThumbnailCanvas).initialOptionalContent = optionalContentConfig.hasInitialVisibility;
            });
          }
          const totalRotation = (this.rotation + this.pdfPageRotate) % 360;
          this.viewport = this.viewport.clone({
            scale: this.scale * _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS,
            rotation: totalRotation
          });
          if (this._isStandalone) {
            _ui_utils.docStyle.setProperty("--scale-factor", this.viewport.scale);
          }
          if (this.svg) {
            this.cssTransform({
              target: this.svg,
              redrawAnnotationLayer: true,
              redrawAnnotationEditorLayer: true,
              redrawXfaLayer: true
            });
            this.eventBus.dispatch("pagerendered", {
              source: this,
              pageNumber: this.id,
              cssTransform: true,
              timestamp: performance.now(),
              error: this._renderError
            });
            return;
          }
          let isScalingRestricted = false;
          if (this.canvas && this.maxCanvasPixels > 0) {
            const outputScale = this.outputScale;
            if ((Math.floor(this.viewport.width) * outputScale.sx | 0) * (Math.floor(this.viewport.height) * outputScale.sy | 0) > this.maxCanvasPixels) {
              isScalingRestricted = true;
            }
          }
          if (this.canvas) {
            if (this.useOnlyCssZoom || this.hasRestrictedScaling && isScalingRestricted) {
              this.cssTransform({
                target: this.canvas,
                redrawAnnotationLayer: true,
                redrawAnnotationEditorLayer: true,
                redrawXfaLayer: true
              });
              this.eventBus.dispatch("pagerendered", {
                source: this,
                pageNumber: this.id,
                cssTransform: true,
                timestamp: performance.now(),
                error: this._renderError
              });
              return;
            }
            if (!this.zoomLayer && !this.canvas.hidden) {
              this.zoomLayer = this.canvas.parentNode;
              this.zoomLayer.style.position = "absolute";
            }
          }
          if (this.zoomLayer) {
            this.cssTransform({
              target: this.zoomLayer.firstChild
            });
          }
          this.reset({
            keepZoomLayer: true,
            keepAnnotationLayer: true,
            keepAnnotationEditorLayer: true,
            keepXfaLayer: true
          });
        }
        cancelRendering({
          keepAnnotationLayer = false,
          keepAnnotationEditorLayer = false,
          keepXfaLayer = false
        } = {}) {
          var _a;
          if (this.paintTask) {
            this.paintTask.cancel();
            this.paintTask = null;
          }
          this.resume = null;
          if (this.textLayer) {
            this.textLayer.cancel();
            this.textLayer = null;
          }
          if (this.annotationLayer && (!keepAnnotationLayer || !this.annotationLayer.div)) {
            this.annotationLayer.cancel();
            this.annotationLayer = null;
            this._annotationCanvasMap = null;
          }
          if (this.annotationEditorLayer && (!keepAnnotationEditorLayer || !this.annotationEditorLayer.div)) {
            this.annotationEditorLayer.cancel();
            this.annotationEditorLayer = null;
          }
          if (this.xfaLayer && (!keepXfaLayer || !this.xfaLayer.div)) {
            this.xfaLayer.cancel();
            this.xfaLayer = null;
            (_a = this.textHighlighter) == null ? void 0 : _a.disable();
          }
          if (this._onTextLayerRendered) {
            this.eventBus._off("textlayerrendered", this._onTextLayerRendered);
            this._onTextLayerRendered = null;
          }
        }
        cssTransform({
          target,
          redrawAnnotationLayer = false,
          redrawAnnotationEditorLayer = false,
          redrawXfaLayer = false
        }) {
          const width = this.viewport.width;
          const height = this.viewport.height;
          const div = this.div;
          target.style.width = target.parentNode.style.width = div.style.width = Math.floor(width) + "px";
          target.style.height = target.parentNode.style.height = div.style.height = Math.floor(height) + "px";
          const relativeRotation = this.viewport.rotation - this.paintedViewportMap.get(target).rotation;
          const absRotation = Math.abs(relativeRotation);
          let scaleX = 1, scaleY = 1;
          if (absRotation === 90 || absRotation === 270) {
            scaleX = height / width;
            scaleY = width / height;
          }
          target.style.transform = `rotate(${relativeRotation}deg) scale(${scaleX}, ${scaleY})`;
          if (this.textLayer) {
            const textLayerViewport = this.textLayer.viewport;
            const textRelativeRotation = this.viewport.rotation - textLayerViewport.rotation;
            const textAbsRotation = Math.abs(textRelativeRotation);
            let scale = width / textLayerViewport.width;
            if (textAbsRotation === 90 || textAbsRotation === 270) {
              scale = width / textLayerViewport.height;
            }
            const textLayerDiv = this.textLayer.textLayerDiv;
            let transX, transY;
            switch (textAbsRotation) {
              case 0:
                transX = transY = 0;
                break;
              case 90:
                transX = 0;
                transY = "-" + textLayerDiv.style.height;
                break;
              case 180:
                transX = "-" + textLayerDiv.style.width;
                transY = "-" + textLayerDiv.style.height;
                break;
              case 270:
                transX = "-" + textLayerDiv.style.width;
                transY = 0;
                break;
              default:
                console.error("Bad rotation value.");
                break;
            }
            textLayerDiv.style.transform = `rotate(${textAbsRotation}deg) scale(${scale}) translate(${transX}, ${transY})`;
            textLayerDiv.style.transformOrigin = "0% 0%";
          }
          if (redrawAnnotationLayer && this.annotationLayer) {
            this._renderAnnotationLayer();
          }
          if (redrawAnnotationEditorLayer && this.annotationEditorLayer) {
            this._renderAnnotationEditorLayer();
          }
          if (redrawXfaLayer && this.xfaLayer) {
            this._renderXfaLayer();
          }
        }
        get width() {
          return this.viewport.width;
        }
        get height() {
          return this.viewport.height;
        }
        getPagePoint(x, y) {
          return this.viewport.convertToPdfPoint(x, y);
        }
        toggleLoadingIconSpinner(viewVisible = false) {
          var _a;
          (_a = this.loadingIconDiv) == null ? void 0 : _a.classList.toggle("notVisible", !viewVisible);
        }
        draw() {
          var _a, _b, _c;
          if (this.renderingState !== _ui_utils.RenderingStates.INITIAL) {
            console.error("Must be in new state before drawing");
            this.reset();
          }
          const {
            div,
            pdfPage
          } = this;
          if (!pdfPage) {
            this.renderingState = _ui_utils.RenderingStates.FINISHED;
            if (this.loadingIconDiv) {
              this.loadingIconDiv.remove();
              delete this.loadingIconDiv;
            }
            return Promise.reject(new Error("pdfPage is not loaded"));
          }
          this.renderingState = _ui_utils.RenderingStates.RUNNING;
          const canvasWrapper = document.createElement("div");
          canvasWrapper.style.width = div.style.width;
          canvasWrapper.style.height = div.style.height;
          canvasWrapper.classList.add("canvasWrapper");
          const lastDivBeforeTextDiv = ((_a = this.annotationLayer) == null ? void 0 : _a.div) || ((_b = this.annotationEditorLayer) == null ? void 0 : _b.div);
          if (lastDivBeforeTextDiv) {
            lastDivBeforeTextDiv.before(canvasWrapper);
          } else {
            div.append(canvasWrapper);
          }
          let textLayer = null;
          if (this.textLayerMode !== _ui_utils.TextLayerMode.DISABLE && this.textLayerFactory) {
            this._accessibilityManager || (this._accessibilityManager = new _text_accessibility.TextAccessibilityManager());
            const textLayerDiv = document.createElement("div");
            textLayerDiv.className = "textLayer";
            textLayerDiv.style.width = canvasWrapper.style.width;
            textLayerDiv.style.height = canvasWrapper.style.height;
            if (lastDivBeforeTextDiv) {
              lastDivBeforeTextDiv.before(textLayerDiv);
            } else {
              div.append(textLayerDiv);
            }
            textLayer = this.textLayerFactory.createTextLayerBuilder({
              textLayerDiv,
              pageIndex: this.id - 1,
              viewport: this.viewport,
              enhanceTextSelection: this.textLayerMode === _ui_utils.TextLayerMode.ENABLE_ENHANCE,
              eventBus: this.eventBus,
              highlighter: this.textHighlighter,
              accessibilityManager: this._accessibilityManager
            });
          }
          this.textLayer = textLayer;
          if (__privateGet(this, _annotationMode) !== _pdfjsLib.AnnotationMode.DISABLE && this.annotationLayerFactory) {
            this._annotationCanvasMap || (this._annotationCanvasMap = /* @__PURE__ */ new Map());
            this.annotationLayer || (this.annotationLayer = this.annotationLayerFactory.createAnnotationLayerBuilder({
              pageDiv: div,
              pdfPage,
              imageResourcesPath: this.imageResourcesPath,
              renderForms: __privateGet(this, _annotationMode) === _pdfjsLib.AnnotationMode.ENABLE_FORMS,
              l10n: this.l10n,
              annotationCanvasMap: this._annotationCanvasMap,
              accessibilityManager: this._accessibilityManager
            }));
          }
          if ((_c = this.xfaLayer) == null ? void 0 : _c.div) {
            div.append(this.xfaLayer.div);
          }
          let renderContinueCallback = null;
          if (this.renderingQueue) {
            renderContinueCallback = (cont) => {
              if (!this.renderingQueue.isHighestPriority(this)) {
                this.renderingState = _ui_utils.RenderingStates.PAUSED;
                this.resume = () => {
                  this.renderingState = _ui_utils.RenderingStates.RUNNING;
                  cont();
                };
                return;
              }
              cont();
            };
          }
          const finishPaintTask = async (error = null) => {
            if (paintTask === this.paintTask) {
              this.paintTask = null;
            }
            if (error instanceof _pdfjsLib.RenderingCancelledException) {
              this._renderError = null;
              return;
            }
            this._renderError = error;
            this.renderingState = _ui_utils.RenderingStates.FINISHED;
            if (this.loadingIconDiv) {
              this.loadingIconDiv.remove();
              delete this.loadingIconDiv;
            }
            this._resetZoomLayer(true);
            __privateGet(this, _useThumbnailCanvas).regularAnnotations = !paintTask.separateAnnots;
            this.eventBus.dispatch("pagerendered", {
              source: this,
              pageNumber: this.id,
              cssTransform: false,
              timestamp: performance.now(),
              error: this._renderError
            });
            if (error) {
              throw error;
            }
          };
          const paintTask = this.renderer === _ui_utils.RendererType.SVG ? this.paintOnSvg(canvasWrapper) : this.paintOnCanvas(canvasWrapper);
          paintTask.onRenderContinue = renderContinueCallback;
          this.paintTask = paintTask;
          const resultPromise = paintTask.promise.then(() => {
            return finishPaintTask(null).then(() => {
              if (textLayer) {
                const readableStream = pdfPage.streamTextContent({
                  includeMarkedContent: true
                });
                textLayer.setTextContentStream(readableStream);
                textLayer.render();
              }
              if (this.annotationLayer) {
                this._renderAnnotationLayer().then(() => {
                  if (this.annotationEditorLayerFactory) {
                    this.annotationEditorLayer || (this.annotationEditorLayer = this.annotationEditorLayerFactory.createAnnotationEditorLayerBuilder({
                      pageDiv: div,
                      pdfPage,
                      l10n: this.l10n,
                      accessibilityManager: this._accessibilityManager
                    }));
                    this._renderAnnotationEditorLayer();
                  }
                });
              }
            });
          }, function(reason) {
            return finishPaintTask(reason);
          });
          if (this.xfaLayerFactory) {
            this.xfaLayer || (this.xfaLayer = this.xfaLayerFactory.createXfaLayerBuilder({
              pageDiv: div,
              pdfPage
            }));
            this._renderXfaLayer();
          }
          if (this.structTreeLayerFactory && this.textLayer && this.canvas) {
            this._onTextLayerRendered = (event) => {
              if (event.pageNumber !== this.id) {
                return;
              }
              this.eventBus._off("textlayerrendered", this._onTextLayerRendered);
              this._onTextLayerRendered = null;
              if (!this.canvas) {
                return;
              }
              this.pdfPage.getStructTree().then((tree) => {
                if (!tree) {
                  return;
                }
                if (!this.canvas) {
                  return;
                }
                const treeDom = this.structTreeLayer.render(tree);
                treeDom.classList.add("structTree");
                this.canvas.append(treeDom);
              });
            };
            this.eventBus._on("textlayerrendered", this._onTextLayerRendered);
            this.structTreeLayer = this.structTreeLayerFactory.createStructTreeLayerBuilder({
              pdfPage
            });
          }
          div.setAttribute("data-loaded", true);
          this.eventBus.dispatch("pagerender", {
            source: this,
            pageNumber: this.id
          });
          return resultPromise;
        }
        paintOnCanvas(canvasWrapper) {
          const renderCapability = (0, _pdfjsLib.createPromiseCapability)();
          const result = {
            promise: renderCapability.promise,
            onRenderContinue(cont) {
              cont();
            },
            cancel() {
              renderTask.cancel();
            },
            get separateAnnots() {
              return renderTask.separateAnnots;
            }
          };
          const viewport = this.viewport;
          const canvas = document.createElement("canvas");
          canvas.setAttribute("role", "presentation");
          canvas.hidden = true;
          let isCanvasHidden = true;
          const showCanvas = function() {
            if (isCanvasHidden) {
              canvas.hidden = false;
              isCanvasHidden = false;
            }
          };
          canvasWrapper.append(canvas);
          this.canvas = canvas;
          const ctx = canvas.getContext("2d", {
            alpha: false
          });
          const outputScale = this.outputScale = new _ui_utils.OutputScale();
          if (this.useOnlyCssZoom) {
            const actualSizeViewport = viewport.clone({
              scale: _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS
            });
            outputScale.sx *= actualSizeViewport.width / viewport.width;
            outputScale.sy *= actualSizeViewport.height / viewport.height;
          }
          if (this.maxCanvasPixels > 0) {
            const pixelsInViewport = viewport.width * viewport.height;
            const maxScale = Math.sqrt(this.maxCanvasPixels / pixelsInViewport);
            if (outputScale.sx > maxScale || outputScale.sy > maxScale) {
              outputScale.sx = maxScale;
              outputScale.sy = maxScale;
              this.hasRestrictedScaling = true;
            } else {
              this.hasRestrictedScaling = false;
            }
          }
          const sfx = (0, _ui_utils.approximateFraction)(outputScale.sx);
          const sfy = (0, _ui_utils.approximateFraction)(outputScale.sy);
          canvas.width = (0, _ui_utils.roundToDivide)(viewport.width * outputScale.sx, sfx[0]);
          canvas.height = (0, _ui_utils.roundToDivide)(viewport.height * outputScale.sy, sfy[0]);
          canvas.style.width = (0, _ui_utils.roundToDivide)(viewport.width, sfx[1]) + "px";
          canvas.style.height = (0, _ui_utils.roundToDivide)(viewport.height, sfy[1]) + "px";
          this.paintedViewportMap.set(canvas, viewport);
          const transform = outputScale.scaled ? [outputScale.sx, 0, 0, outputScale.sy, 0, 0] : null;
          const renderContext = {
            canvasContext: ctx,
            transform,
            viewport: this.viewport,
            annotationMode: __privateGet(this, _annotationMode),
            optionalContentConfigPromise: this._optionalContentConfigPromise,
            annotationCanvasMap: this._annotationCanvasMap,
            pageColors: this.pageColors
          };
          const renderTask = this.pdfPage.render(renderContext);
          renderTask.onContinue = function(cont) {
            showCanvas();
            if (result.onRenderContinue) {
              result.onRenderContinue(cont);
            } else {
              cont();
            }
          };
          renderTask.promise.then(function() {
            showCanvas();
            renderCapability.resolve();
          }, function(error) {
            showCanvas();
            renderCapability.reject(error);
          });
          return result;
        }
        paintOnSvg(wrapper) {
          let cancelled = false;
          const ensureNotCancelled = () => {
            if (cancelled) {
              throw new _pdfjsLib.RenderingCancelledException(`Rendering cancelled, page ${this.id}`, "svg");
            }
          };
          const pdfPage = this.pdfPage;
          const actualSizeViewport = this.viewport.clone({
            scale: _pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS
          });
          const promise = pdfPage.getOperatorList({
            annotationMode: __privateGet(this, _annotationMode)
          }).then((opList) => {
            ensureNotCancelled();
            const svgGfx = new _pdfjsLib.SVGGraphics(pdfPage.commonObjs, pdfPage.objs);
            return svgGfx.getSVG(opList, actualSizeViewport).then((svg) => {
              ensureNotCancelled();
              this.svg = svg;
              this.paintedViewportMap.set(svg, actualSizeViewport);
              svg.style.width = wrapper.style.width;
              svg.style.height = wrapper.style.height;
              this.renderingState = _ui_utils.RenderingStates.FINISHED;
              wrapper.append(svg);
            });
          });
          return {
            promise,
            onRenderContinue(cont) {
              cont();
            },
            cancel() {
              cancelled = true;
            },
            get separateAnnots() {
              return false;
            }
          };
        }
        setPageLabel(label) {
          this.pageLabel = typeof label === "string" ? label : null;
          if (this.pageLabel !== null) {
            this.div.setAttribute("data-page-label", this.pageLabel);
          } else {
            this.div.removeAttribute("data-page-label");
          }
        }
        get thumbnailCanvas() {
          const {
            initialOptionalContent,
            regularAnnotations
          } = __privateGet(this, _useThumbnailCanvas);
          return initialOptionalContent && regularAnnotations ? this.canvas : null;
        }
      }
      _annotationMode = new WeakMap();
      _useThumbnailCanvas = new WeakMap();
      exports.PDFPageView = PDFPageView;
    }),
    /* 34 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _enabled, _textChildren, _textNodes, _waitingElements, _TextAccessibilityManager_static, compareElementPositions_fn, _TextAccessibilityManager_instances, addIdToAriaOwns_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.TextAccessibilityManager = void 0;
      var _ui_utils = __webpack_require__2(1);
      const _TextAccessibilityManager = class _TextAccessibilityManager {
        constructor() {
          __privateAdd(this, _TextAccessibilityManager_instances);
          __privateAdd(this, _enabled, false);
          __privateAdd(this, _textChildren, null);
          __privateAdd(this, _textNodes, /* @__PURE__ */ new Map());
          __privateAdd(this, _waitingElements, /* @__PURE__ */ new Map());
        }
        setTextMapping(textDivs) {
          __privateSet(this, _textChildren, textDivs);
        }
        enable() {
          if (__privateGet(this, _enabled)) {
            throw new Error("TextAccessibilityManager is already enabled.");
          }
          if (!__privateGet(this, _textChildren)) {
            throw new Error("Text divs and strings have not been set.");
          }
          __privateSet(this, _enabled, true);
          __privateSet(this, _textChildren, __privateGet(this, _textChildren).slice());
          __privateGet(this, _textChildren).sort(__privateMethod(_TextAccessibilityManager, _TextAccessibilityManager_static, compareElementPositions_fn));
          if (__privateGet(this, _textNodes).size > 0) {
            const textChildren = __privateGet(this, _textChildren);
            for (const [id, nodeIndex] of __privateGet(this, _textNodes)) {
              const element = document.getElementById(id);
              if (!element) {
                __privateGet(this, _textNodes).delete(id);
                continue;
              }
              __privateMethod(this, _TextAccessibilityManager_instances, addIdToAriaOwns_fn).call(this, id, textChildren[nodeIndex]);
            }
          }
          for (const [element, isRemovable] of __privateGet(this, _waitingElements)) {
            this.addPointerInTextLayer(element, isRemovable);
          }
          __privateGet(this, _waitingElements).clear();
        }
        disable() {
          if (!__privateGet(this, _enabled)) {
            return;
          }
          __privateGet(this, _waitingElements).clear();
          __privateSet(this, _textChildren, null);
          __privateSet(this, _enabled, false);
        }
        removePointerInTextLayer(element) {
          if (!__privateGet(this, _enabled)) {
            __privateGet(this, _waitingElements).delete(element);
            return;
          }
          const children = __privateGet(this, _textChildren);
          if (!children || children.length === 0) {
            return;
          }
          const {
            id
          } = element;
          const nodeIndex = __privateGet(this, _textNodes).get(id);
          if (nodeIndex === void 0) {
            return;
          }
          const node = children[nodeIndex];
          __privateGet(this, _textNodes).delete(id);
          let owns = node.getAttribute("aria-owns");
          if (owns == null ? void 0 : owns.includes(id)) {
            owns = owns.split(" ").filter((x) => x !== id).join(" ");
            if (owns) {
              node.setAttribute("aria-owns", owns);
            } else {
              node.removeAttribute("aria-owns");
              node.setAttribute("role", "presentation");
            }
          }
        }
        addPointerInTextLayer(element, isRemovable) {
          const {
            id
          } = element;
          if (!id) {
            return;
          }
          if (!__privateGet(this, _enabled)) {
            __privateGet(this, _waitingElements).set(element, isRemovable);
            return;
          }
          if (isRemovable) {
            this.removePointerInTextLayer(element);
          }
          const children = __privateGet(this, _textChildren);
          if (!children || children.length === 0) {
            return;
          }
          const index = (0, _ui_utils.binarySearchFirstItem)(children, (node) => {
            var _a;
            return __privateMethod(_a = _TextAccessibilityManager, _TextAccessibilityManager_static, compareElementPositions_fn).call(_a, element, node) < 0;
          });
          const nodeIndex = Math.max(0, index - 1);
          __privateMethod(this, _TextAccessibilityManager_instances, addIdToAriaOwns_fn).call(this, id, children[nodeIndex]);
          __privateGet(this, _textNodes).set(id, nodeIndex);
        }
        moveElementInDOM(container, element, contentElement, isRemovable) {
          this.addPointerInTextLayer(contentElement, isRemovable);
          if (!container.hasChildNodes()) {
            container.append(element);
            return;
          }
          const children = Array.from(container.childNodes).filter((node) => node !== element);
          if (children.length === 0) {
            return;
          }
          const elementToCompare = contentElement || element;
          const index = (0, _ui_utils.binarySearchFirstItem)(children, (node) => {
            var _a;
            return __privateMethod(_a = _TextAccessibilityManager, _TextAccessibilityManager_static, compareElementPositions_fn).call(_a, elementToCompare, node) < 0;
          });
          if (index === 0) {
            children[0].before(element);
          } else {
            children[index - 1].after(element);
          }
        }
      };
      _enabled = new WeakMap();
      _textChildren = new WeakMap();
      _textNodes = new WeakMap();
      _waitingElements = new WeakMap();
      _TextAccessibilityManager_static = new WeakSet();
      compareElementPositions_fn = function(e1, e2) {
        const rect1 = e1.getBoundingClientRect();
        const rect2 = e2.getBoundingClientRect();
        if (rect1.width === 0 && rect1.height === 0) {
          return 1;
        }
        if (rect2.width === 0 && rect2.height === 0) {
          return -1;
        }
        const top1 = rect1.y;
        const bot1 = rect1.y + rect1.height;
        const mid1 = rect1.y + rect1.height / 2;
        const top2 = rect2.y;
        const bot2 = rect2.y + rect2.height;
        const mid2 = rect2.y + rect2.height / 2;
        if (mid1 <= top2 && mid2 >= bot1) {
          return -1;
        }
        if (mid2 <= top1 && mid1 >= bot2) {
          return 1;
        }
        const centerX1 = rect1.x + rect1.width / 2;
        const centerX2 = rect2.x + rect2.width / 2;
        return centerX1 - centerX2;
      };
      _TextAccessibilityManager_instances = new WeakSet();
      addIdToAriaOwns_fn = function(id, node) {
        const owns = node.getAttribute("aria-owns");
        if (!(owns == null ? void 0 : owns.includes(id))) {
          node.setAttribute("aria-owns", owns ? `${owns} ${id}` : id);
        }
        node.removeAttribute("role");
      };
      __privateAdd(_TextAccessibilityManager, _TextAccessibilityManager_static);
      let TextAccessibilityManager = _TextAccessibilityManager;
      exports.TextAccessibilityManager = TextAccessibilityManager;
    }),
    /* 35 */
    /***/
    ((__unused_webpack_module, exports) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.StructTreeLayerBuilder = void 0;
      const PDF_ROLE_TO_HTML_ROLE = {
        Document: null,
        DocumentFragment: null,
        Part: "group",
        Sect: "group",
        Div: "group",
        Aside: "note",
        NonStruct: "none",
        P: null,
        H: "heading",
        Title: null,
        FENote: "note",
        Sub: "group",
        Lbl: null,
        Span: null,
        Em: null,
        Strong: null,
        Link: "link",
        Annot: "note",
        Form: "form",
        Ruby: null,
        RB: null,
        RT: null,
        RP: null,
        Warichu: null,
        WT: null,
        WP: null,
        L: "list",
        LI: "listitem",
        LBody: null,
        Table: "table",
        TR: "row",
        TH: "columnheader",
        TD: "cell",
        THead: "columnheader",
        TBody: null,
        TFoot: null,
        Caption: null,
        Figure: "figure",
        Formula: null,
        Artifact: null
      };
      const HEADING_PATTERN = /^H(\d+)$/;
      class StructTreeLayerBuilder {
        constructor({
          pdfPage
        }) {
          this.pdfPage = pdfPage;
        }
        render(structTree) {
          return this._walk(structTree);
        }
        _setAttributes(structElement, htmlElement) {
          if (structElement.alt !== void 0) {
            htmlElement.setAttribute("aria-label", structElement.alt);
          }
          if (structElement.id !== void 0) {
            htmlElement.setAttribute("aria-owns", structElement.id);
          }
          if (structElement.lang !== void 0) {
            htmlElement.setAttribute("lang", structElement.lang);
          }
        }
        _walk(node) {
          if (!node) {
            return null;
          }
          const element = document.createElement("span");
          if ("role" in node) {
            const {
              role
            } = node;
            const match = role.match(HEADING_PATTERN);
            if (match) {
              element.setAttribute("role", "heading");
              element.setAttribute("aria-level", match[1]);
            } else if (PDF_ROLE_TO_HTML_ROLE[role]) {
              element.setAttribute("role", PDF_ROLE_TO_HTML_ROLE[role]);
            }
          }
          this._setAttributes(node, element);
          if (node.children) {
            if (node.children.length === 1 && "id" in node.children[0]) {
              this._setAttributes(node.children[0], element);
            } else {
              for (const kid of node.children) {
                element.append(this._walk(kid));
              }
            }
          }
          return element;
        }
      }
      exports.StructTreeLayerBuilder = StructTreeLayerBuilder;
    }),
    /* 36 */
    /***/
    ((__unused_webpack_module, exports) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.TextHighlighter = void 0;
      class TextHighlighter {
        constructor({
          findController,
          eventBus,
          pageIndex
        }) {
          this.findController = findController;
          this.matches = [];
          this.eventBus = eventBus;
          this.pageIdx = pageIndex;
          this._onUpdateTextLayerMatches = null;
          this.textDivs = null;
          this.textContentItemsStr = null;
          this.enabled = false;
        }
        setTextMapping(divs, texts) {
          this.textDivs = divs;
          this.textContentItemsStr = texts;
        }
        enable() {
          if (!this.textDivs || !this.textContentItemsStr) {
            throw new Error("Text divs and strings have not been set.");
          }
          if (this.enabled) {
            throw new Error("TextHighlighter is already enabled.");
          }
          this.enabled = true;
          if (!this._onUpdateTextLayerMatches) {
            this._onUpdateTextLayerMatches = (evt) => {
              if (evt.pageIndex === this.pageIdx || evt.pageIndex === -1) {
                this._updateMatches();
              }
            };
            this.eventBus._on("updatetextlayermatches", this._onUpdateTextLayerMatches);
          }
          this._updateMatches();
        }
        disable() {
          if (!this.enabled) {
            return;
          }
          this.enabled = false;
          if (this._onUpdateTextLayerMatches) {
            this.eventBus._off("updatetextlayermatches", this._onUpdateTextLayerMatches);
            this._onUpdateTextLayerMatches = null;
          }
        }
        _convertMatches(matches, matchesLength) {
          if (!matches) {
            return [];
          }
          const {
            textContentItemsStr
          } = this;
          let i = 0, iIndex = 0;
          const end = textContentItemsStr.length - 1;
          const result = [];
          for (let m = 0, mm = matches.length; m < mm; m++) {
            let matchIdx = matches[m];
            while (i !== end && matchIdx >= iIndex + textContentItemsStr[i].length) {
              iIndex += textContentItemsStr[i].length;
              i++;
            }
            if (i === textContentItemsStr.length) {
              console.error("Could not find a matching mapping");
            }
            const match = {
              begin: {
                divIdx: i,
                offset: matchIdx - iIndex
              }
            };
            matchIdx += matchesLength[m];
            while (i !== end && matchIdx > iIndex + textContentItemsStr[i].length) {
              iIndex += textContentItemsStr[i].length;
              i++;
            }
            match.end = {
              divIdx: i,
              offset: matchIdx - iIndex
            };
            result.push(match);
          }
          return result;
        }
        _renderMatches(matches) {
          if (matches.length === 0) {
            return;
          }
          const {
            findController,
            pageIdx
          } = this;
          const {
            textContentItemsStr,
            textDivs
          } = this;
          const isSelectedPage = pageIdx === findController.selected.pageIdx;
          const selectedMatchIdx = findController.selected.matchIdx;
          const highlightAll = findController.state.highlightAll;
          let prevEnd = null;
          const infinity = {
            divIdx: -1,
            offset: void 0
          };
          function beginText(begin, className) {
            const divIdx = begin.divIdx;
            textDivs[divIdx].textContent = "";
            return appendTextToDiv(divIdx, 0, begin.offset, className);
          }
          function appendTextToDiv(divIdx, fromOffset, toOffset, className) {
            let div = textDivs[divIdx];
            if (div.nodeType === Node.TEXT_NODE) {
              const span = document.createElement("span");
              div.before(span);
              span.append(div);
              textDivs[divIdx] = span;
              div = span;
            }
            const content = textContentItemsStr[divIdx].substring(fromOffset, toOffset);
            const node = document.createTextNode(content);
            if (className) {
              const span = document.createElement("span");
              span.className = `${className} appended`;
              span.append(node);
              div.append(span);
              return className.includes("selected") ? span.offsetLeft : 0;
            }
            div.append(node);
            return 0;
          }
          let i0 = selectedMatchIdx, i1 = i0 + 1;
          if (highlightAll) {
            i0 = 0;
            i1 = matches.length;
          } else if (!isSelectedPage) {
            return;
          }
          for (let i = i0; i < i1; i++) {
            const match = matches[i];
            const begin = match.begin;
            const end = match.end;
            const isSelected = isSelectedPage && i === selectedMatchIdx;
            const highlightSuffix = isSelected ? " selected" : "";
            let selectedLeft = 0;
            if (!prevEnd || begin.divIdx !== prevEnd.divIdx) {
              if (prevEnd !== null) {
                appendTextToDiv(prevEnd.divIdx, prevEnd.offset, infinity.offset);
              }
              beginText(begin);
            } else {
              appendTextToDiv(prevEnd.divIdx, prevEnd.offset, begin.offset);
            }
            if (begin.divIdx === end.divIdx) {
              selectedLeft = appendTextToDiv(begin.divIdx, begin.offset, end.offset, "highlight" + highlightSuffix);
            } else {
              selectedLeft = appendTextToDiv(begin.divIdx, begin.offset, infinity.offset, "highlight begin" + highlightSuffix);
              for (let n0 = begin.divIdx + 1, n1 = end.divIdx; n0 < n1; n0++) {
                textDivs[n0].className = "highlight middle" + highlightSuffix;
              }
              beginText(end, "highlight end" + highlightSuffix);
            }
            prevEnd = end;
            if (isSelected) {
              findController.scrollMatchIntoView({
                element: textDivs[begin.divIdx],
                selectedLeft,
                pageIndex: pageIdx,
                matchIndex: selectedMatchIdx
              });
            }
          }
          if (prevEnd) {
            appendTextToDiv(prevEnd.divIdx, prevEnd.offset, infinity.offset);
          }
        }
        _updateMatches() {
          if (!this.enabled) {
            return;
          }
          const {
            findController,
            matches,
            pageIdx
          } = this;
          const {
            textContentItemsStr,
            textDivs
          } = this;
          let clearedUntilDivIdx = -1;
          for (let i = 0, ii = matches.length; i < ii; i++) {
            const match = matches[i];
            const begin = Math.max(clearedUntilDivIdx, match.begin.divIdx);
            for (let n = begin, end = match.end.divIdx; n <= end; n++) {
              const div = textDivs[n];
              div.textContent = textContentItemsStr[n];
              div.className = "";
            }
            clearedUntilDivIdx = match.end.divIdx + 1;
          }
          if (!(findController == null ? void 0 : findController.highlightMatches)) {
            return;
          }
          const pageMatches = findController.pageMatches[pageIdx] || null;
          const pageMatchesLength = findController.pageMatchesLength[pageIdx] || null;
          this.matches = this._convertMatches(pageMatches, pageMatchesLength);
          this._renderMatches(this.matches);
        }
      }
      exports.TextHighlighter = TextHighlighter;
    }),
    /* 37 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.TextLayerBuilder = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      const EXPAND_DIVS_TIMEOUT = 300;
      class TextLayerBuilder {
        constructor({
          textLayerDiv,
          eventBus,
          pageIndex,
          viewport,
          highlighter = null,
          enhanceTextSelection = false,
          accessibilityManager = null
        }) {
          this.textLayerDiv = textLayerDiv;
          this.eventBus = eventBus;
          this.textContent = null;
          this.textContentItemsStr = [];
          this.textContentStream = null;
          this.renderingDone = false;
          this.pageNumber = pageIndex + 1;
          this.viewport = viewport;
          this.textDivs = [];
          this.textLayerRenderTask = null;
          this.highlighter = highlighter;
          this.enhanceTextSelection = enhanceTextSelection;
          this.accessibilityManager = accessibilityManager;
          this._bindMouse();
        }
        _finishRendering() {
          this.renderingDone = true;
          if (!this.enhanceTextSelection) {
            const endOfContent = document.createElement("div");
            endOfContent.className = "endOfContent";
            this.textLayerDiv.append(endOfContent);
          }
          this.eventBus.dispatch("textlayerrendered", {
            source: this,
            pageNumber: this.pageNumber,
            numTextDivs: this.textDivs.length
          });
        }
        render(timeout = 0) {
          var _a, _b;
          if (!(this.textContent || this.textContentStream) || this.renderingDone) {
            return;
          }
          this.cancel();
          this.textDivs.length = 0;
          (_a = this.highlighter) == null ? void 0 : _a.setTextMapping(this.textDivs, this.textContentItemsStr);
          (_b = this.accessibilityManager) == null ? void 0 : _b.setTextMapping(this.textDivs);
          const textLayerFrag = document.createDocumentFragment();
          this.textLayerRenderTask = (0, _pdfjsLib.renderTextLayer)({
            textContent: this.textContent,
            textContentStream: this.textContentStream,
            container: textLayerFrag,
            viewport: this.viewport,
            textDivs: this.textDivs,
            textContentItemsStr: this.textContentItemsStr,
            timeout,
            enhanceTextSelection: this.enhanceTextSelection
          });
          this.textLayerRenderTask.promise.then(() => {
            var _a2, _b2;
            this.textLayerDiv.append(textLayerFrag);
            this._finishRendering();
            (_a2 = this.highlighter) == null ? void 0 : _a2.enable();
            (_b2 = this.accessibilityManager) == null ? void 0 : _b2.enable();
          }, function(reason) {
          });
        }
        cancel() {
          var _a, _b;
          if (this.textLayerRenderTask) {
            this.textLayerRenderTask.cancel();
            this.textLayerRenderTask = null;
          }
          (_a = this.highlighter) == null ? void 0 : _a.disable();
          (_b = this.accessibilityManager) == null ? void 0 : _b.disable();
        }
        setTextContentStream(readableStream) {
          this.cancel();
          this.textContentStream = readableStream;
        }
        setTextContent(textContent) {
          this.cancel();
          this.textContent = textContent;
        }
        _bindMouse() {
          const div = this.textLayerDiv;
          let expandDivsTimer = null;
          div.addEventListener("mousedown", (evt) => {
            if (this.enhanceTextSelection && this.textLayerRenderTask) {
              this.textLayerRenderTask.expandTextDivs(true);
              if (expandDivsTimer) {
                clearTimeout(expandDivsTimer);
                expandDivsTimer = null;
              }
              return;
            }
            const end = div.querySelector(".endOfContent");
            if (!end) {
              return;
            }
            let adjustTop = evt.target !== div;
            adjustTop = adjustTop && window.getComputedStyle(end).getPropertyValue("-moz-user-select") !== "none";
            if (adjustTop) {
              const divBounds = div.getBoundingClientRect();
              const r = Math.max(0, (evt.pageY - divBounds.top) / divBounds.height);
              end.style.top = (r * 100).toFixed(2) + "%";
            }
            end.classList.add("active");
          });
          div.addEventListener("mouseup", () => {
            if (this.enhanceTextSelection && this.textLayerRenderTask) {
              expandDivsTimer = setTimeout(() => {
                if (this.textLayerRenderTask) {
                  this.textLayerRenderTask.expandTextDivs(false);
                }
                expandDivsTimer = null;
              }, EXPAND_DIVS_TIMEOUT);
              return;
            }
            const end = div.querySelector(".endOfContent");
            if (!end) {
              return;
            }
            end.style.top = "";
            end.classList.remove("active");
          });
        }
      }
      exports.TextLayerBuilder = TextLayerBuilder;
    }),
    /* 38 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.XfaLayerBuilder = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      class XfaLayerBuilder {
        constructor({
          pageDiv,
          pdfPage,
          annotationStorage = null,
          linkService,
          xfaHtml = null
        }) {
          this.pageDiv = pageDiv;
          this.pdfPage = pdfPage;
          this.annotationStorage = annotationStorage;
          this.linkService = linkService;
          this.xfaHtml = xfaHtml;
          this.div = null;
          this._cancelled = false;
        }
        render(viewport, intent = "display") {
          if (intent === "print") {
            const parameters = {
              viewport: viewport.clone({
                dontFlip: true
              }),
              div: this.div,
              xfaHtml: this.xfaHtml,
              annotationStorage: this.annotationStorage,
              linkService: this.linkService,
              intent
            };
            const div = document.createElement("div");
            this.pageDiv.append(div);
            parameters.div = div;
            const result = _pdfjsLib.XfaLayer.render(parameters);
            return Promise.resolve(result);
          }
          return this.pdfPage.getXfa().then((xfaHtml) => {
            if (this._cancelled || !xfaHtml) {
              return {
                textDivs: []
              };
            }
            const parameters = {
              viewport: viewport.clone({
                dontFlip: true
              }),
              div: this.div,
              xfaHtml,
              annotationStorage: this.annotationStorage,
              linkService: this.linkService,
              intent
            };
            if (this.div) {
              return _pdfjsLib.XfaLayer.update(parameters);
            }
            this.div = document.createElement("div");
            this.pageDiv.append(this.div);
            parameters.div = this.div;
            return _pdfjsLib.XfaLayer.render(parameters);
          }).catch((error) => {
            console.error(error);
          });
        }
        cancel() {
          this._cancelled = true;
        }
        hide() {
          if (!this.div) {
            return;
          }
          this.div.hidden = true;
        }
      }
      exports.XfaLayerBuilder = XfaLayerBuilder;
    }),
    /* 39 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _SecondaryToolbar_instances, updateUIState_fn, bindClickListeners_fn, bindCursorToolsListener_fn, bindScrollModeListener_fn, bindSpreadModeListener_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.SecondaryToolbar = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _pdf_cursor_tools = __webpack_require__2(7);
      var _base_viewer = __webpack_require__2(29);
      class SecondaryToolbar {
        constructor(options, eventBus) {
          __privateAdd(this, _SecondaryToolbar_instances);
          this.toolbar = options.toolbar;
          this.toggleButton = options.toggleButton;
          this.buttons = [{
            element: options.presentationModeButton,
            eventName: "presentationmode",
            close: true
          }, {
            element: options.printButton,
            eventName: "print",
            close: true
          }, {
            element: options.downloadButton,
            eventName: "download",
            close: true
          }, {
            element: options.viewBookmarkButton,
            eventName: null,
            close: true
          }, {
            element: options.firstPageButton,
            eventName: "firstpage",
            close: true
          }, {
            element: options.lastPageButton,
            eventName: "lastpage",
            close: true
          }, {
            element: options.pageRotateCwButton,
            eventName: "rotatecw",
            close: false
          }, {
            element: options.pageRotateCcwButton,
            eventName: "rotateccw",
            close: false
          }, {
            element: options.cursorSelectToolButton,
            eventName: "switchcursortool",
            eventDetails: {
              tool: _pdf_cursor_tools.CursorTool.SELECT
            },
            close: true
          }, {
            element: options.cursorHandToolButton,
            eventName: "switchcursortool",
            eventDetails: {
              tool: _pdf_cursor_tools.CursorTool.HAND
            },
            close: true
          }, {
            element: options.scrollPageButton,
            eventName: "switchscrollmode",
            eventDetails: {
              mode: _ui_utils.ScrollMode.PAGE
            },
            close: true
          }, {
            element: options.scrollVerticalButton,
            eventName: "switchscrollmode",
            eventDetails: {
              mode: _ui_utils.ScrollMode.VERTICAL
            },
            close: true
          }, {
            element: options.scrollHorizontalButton,
            eventName: "switchscrollmode",
            eventDetails: {
              mode: _ui_utils.ScrollMode.HORIZONTAL
            },
            close: true
          }, {
            element: options.scrollWrappedButton,
            eventName: "switchscrollmode",
            eventDetails: {
              mode: _ui_utils.ScrollMode.WRAPPED
            },
            close: true
          }, {
            element: options.spreadNoneButton,
            eventName: "switchspreadmode",
            eventDetails: {
              mode: _ui_utils.SpreadMode.NONE
            },
            close: true
          }, {
            element: options.spreadOddButton,
            eventName: "switchspreadmode",
            eventDetails: {
              mode: _ui_utils.SpreadMode.ODD
            },
            close: true
          }, {
            element: options.spreadEvenButton,
            eventName: "switchspreadmode",
            eventDetails: {
              mode: _ui_utils.SpreadMode.EVEN
            },
            close: true
          }, {
            element: options.documentPropertiesButton,
            eventName: "documentproperties",
            close: true
          }];
          this.buttons.push({
            element: options.openFileButton,
            eventName: "openfile",
            close: true
          });
          this.items = {
            firstPage: options.firstPageButton,
            lastPage: options.lastPageButton,
            pageRotateCw: options.pageRotateCwButton,
            pageRotateCcw: options.pageRotateCcwButton
          };
          this.eventBus = eventBus;
          this.opened = false;
          __privateMethod(this, _SecondaryToolbar_instances, bindClickListeners_fn).call(this);
          __privateMethod(this, _SecondaryToolbar_instances, bindCursorToolsListener_fn).call(this, options);
          __privateMethod(this, _SecondaryToolbar_instances, bindScrollModeListener_fn).call(this, options);
          __privateMethod(this, _SecondaryToolbar_instances, bindSpreadModeListener_fn).call(this, options);
          this.reset();
        }
        get isOpen() {
          return this.opened;
        }
        setPageNumber(pageNumber) {
          this.pageNumber = pageNumber;
          __privateMethod(this, _SecondaryToolbar_instances, updateUIState_fn).call(this);
        }
        setPagesCount(pagesCount) {
          this.pagesCount = pagesCount;
          __privateMethod(this, _SecondaryToolbar_instances, updateUIState_fn).call(this);
        }
        reset() {
          this.pageNumber = 0;
          this.pagesCount = 0;
          __privateMethod(this, _SecondaryToolbar_instances, updateUIState_fn).call(this);
          this.eventBus.dispatch("secondarytoolbarreset", {
            source: this
          });
        }
        open() {
          if (this.opened) {
            return;
          }
          this.opened = true;
          this.toggleButton.classList.add("toggled");
          this.toggleButton.setAttribute("aria-expanded", "true");
          this.toolbar.classList.remove("hidden");
        }
        close() {
          if (!this.opened) {
            return;
          }
          this.opened = false;
          this.toolbar.classList.add("hidden");
          this.toggleButton.classList.remove("toggled");
          this.toggleButton.setAttribute("aria-expanded", "false");
        }
        toggle() {
          if (this.opened) {
            this.close();
          } else {
            this.open();
          }
        }
      }
      _SecondaryToolbar_instances = new WeakSet();
      updateUIState_fn = function() {
        this.items.firstPage.disabled = this.pageNumber <= 1;
        this.items.lastPage.disabled = this.pageNumber >= this.pagesCount;
        this.items.pageRotateCw.disabled = this.pagesCount === 0;
        this.items.pageRotateCcw.disabled = this.pagesCount === 0;
      };
      bindClickListeners_fn = function() {
        this.toggleButton.addEventListener("click", this.toggle.bind(this));
        for (const {
          element,
          eventName,
          close,
          eventDetails
        } of this.buttons) {
          element.addEventListener("click", (evt) => {
            if (eventName !== null) {
              const details = {
                source: this
              };
              for (const property in eventDetails) {
                details[property] = eventDetails[property];
              }
              this.eventBus.dispatch(eventName, details);
            }
            if (close) {
              this.close();
            }
          });
        }
      };
      bindCursorToolsListener_fn = function({
        cursorSelectToolButton,
        cursorHandToolButton
      }) {
        this.eventBus._on("cursortoolchanged", function({
          tool
        }) {
          const isSelect = tool === _pdf_cursor_tools.CursorTool.SELECT, isHand = tool === _pdf_cursor_tools.CursorTool.HAND;
          cursorSelectToolButton.classList.toggle("toggled", isSelect);
          cursorHandToolButton.classList.toggle("toggled", isHand);
          cursorSelectToolButton.setAttribute("aria-checked", isSelect);
          cursorHandToolButton.setAttribute("aria-checked", isHand);
        });
      };
      bindScrollModeListener_fn = function({
        scrollPageButton,
        scrollVerticalButton,
        scrollHorizontalButton,
        scrollWrappedButton,
        spreadNoneButton,
        spreadOddButton,
        spreadEvenButton
      }) {
        const scrollModeChanged = ({
          mode
        }) => {
          const isPage = mode === _ui_utils.ScrollMode.PAGE, isVertical = mode === _ui_utils.ScrollMode.VERTICAL, isHorizontal = mode === _ui_utils.ScrollMode.HORIZONTAL, isWrapped = mode === _ui_utils.ScrollMode.WRAPPED;
          scrollPageButton.classList.toggle("toggled", isPage);
          scrollVerticalButton.classList.toggle("toggled", isVertical);
          scrollHorizontalButton.classList.toggle("toggled", isHorizontal);
          scrollWrappedButton.classList.toggle("toggled", isWrapped);
          scrollPageButton.setAttribute("aria-checked", isPage);
          scrollVerticalButton.setAttribute("aria-checked", isVertical);
          scrollHorizontalButton.setAttribute("aria-checked", isHorizontal);
          scrollWrappedButton.setAttribute("aria-checked", isWrapped);
          const forceScrollModePage = this.pagesCount > _base_viewer.PagesCountLimit.FORCE_SCROLL_MODE_PAGE;
          scrollPageButton.disabled = forceScrollModePage;
          scrollVerticalButton.disabled = forceScrollModePage;
          scrollHorizontalButton.disabled = forceScrollModePage;
          scrollWrappedButton.disabled = forceScrollModePage;
          spreadNoneButton.disabled = isHorizontal;
          spreadOddButton.disabled = isHorizontal;
          spreadEvenButton.disabled = isHorizontal;
        };
        this.eventBus._on("scrollmodechanged", scrollModeChanged);
        this.eventBus._on("secondarytoolbarreset", (evt) => {
          if (evt.source === this) {
            scrollModeChanged({
              mode: _ui_utils.ScrollMode.VERTICAL
            });
          }
        });
      };
      bindSpreadModeListener_fn = function({
        spreadNoneButton,
        spreadOddButton,
        spreadEvenButton
      }) {
        function spreadModeChanged({
          mode
        }) {
          const isNone = mode === _ui_utils.SpreadMode.NONE, isOdd = mode === _ui_utils.SpreadMode.ODD, isEven = mode === _ui_utils.SpreadMode.EVEN;
          spreadNoneButton.classList.toggle("toggled", isNone);
          spreadOddButton.classList.toggle("toggled", isOdd);
          spreadEvenButton.classList.toggle("toggled", isEven);
          spreadNoneButton.setAttribute("aria-checked", isNone);
          spreadOddButton.setAttribute("aria-checked", isOdd);
          spreadEvenButton.setAttribute("aria-checked", isEven);
        }
        this.eventBus._on("spreadmodechanged", spreadModeChanged);
        this.eventBus._on("secondarytoolbarreset", (evt) => {
          if (evt.source === this) {
            spreadModeChanged({
              mode: _ui_utils.SpreadMode.NONE
            });
          }
        });
      };
      exports.SecondaryToolbar = SecondaryToolbar;
    }),
    /* 40 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _wasLocalized, _Toolbar_instances, bindListeners_fn, bindEditorToolsListener_fn, updateUIState_fn, adjustScaleWidth_fn;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.Toolbar = void 0;
      var _ui_utils = __webpack_require__2(1);
      var _pdfjsLib = __webpack_require__2(5);
      const PAGE_NUMBER_LOADING_INDICATOR = "visiblePageIsLoading";
      class Toolbar {
        constructor(options, eventBus, l10n) {
          __privateAdd(this, _Toolbar_instances);
          __privateAdd(this, _wasLocalized, false);
          this.toolbar = options.container;
          this.eventBus = eventBus;
          this.l10n = l10n;
          this.buttons = [{
            element: options.previous,
            eventName: "previouspage"
          }, {
            element: options.next,
            eventName: "nextpage"
          }, {
            element: options.zoomIn,
            eventName: "zoomin"
          }, {
            element: options.zoomOut,
            eventName: "zoomout"
          }, {
            element: options.print,
            eventName: "print"
          }, {
            element: options.presentationModeButton,
            eventName: "presentationmode"
          }, {
            element: options.download,
            eventName: "download"
          }, {
            element: options.viewBookmark,
            eventName: null
          }, {
            element: options.editorFreeTextButton,
            eventName: "switchannotationeditormode",
            eventDetails: {
              get mode() {
                const {
                  classList
                } = options.editorFreeTextButton;
                return classList.contains("toggled") ? _pdfjsLib.AnnotationEditorType.NONE : _pdfjsLib.AnnotationEditorType.FREETEXT;
              }
            }
          }, {
            element: options.editorInkButton,
            eventName: "switchannotationeditormode",
            eventDetails: {
              get mode() {
                const {
                  classList
                } = options.editorInkButton;
                return classList.contains("toggled") ? _pdfjsLib.AnnotationEditorType.NONE : _pdfjsLib.AnnotationEditorType.INK;
              }
            }
          }];
          this.buttons.push({
            element: options.openFile,
            eventName: "openfile"
          });
          this.items = {
            numPages: options.numPages,
            pageNumber: options.pageNumber,
            scaleSelect: options.scaleSelect,
            customScaleOption: options.customScaleOption,
            previous: options.previous,
            next: options.next,
            zoomIn: options.zoomIn,
            zoomOut: options.zoomOut
          };
          __privateMethod(this, _Toolbar_instances, bindListeners_fn).call(this, options);
          this.reset();
        }
        setPageNumber(pageNumber, pageLabel) {
          this.pageNumber = pageNumber;
          this.pageLabel = pageLabel;
          __privateMethod(this, _Toolbar_instances, updateUIState_fn).call(this, false);
        }
        setPagesCount(pagesCount, hasPageLabels) {
          this.pagesCount = pagesCount;
          this.hasPageLabels = hasPageLabels;
          __privateMethod(this, _Toolbar_instances, updateUIState_fn).call(this, true);
        }
        setPageScale(pageScaleValue, pageScale) {
          this.pageScaleValue = (pageScaleValue || pageScale).toString();
          this.pageScale = pageScale;
          __privateMethod(this, _Toolbar_instances, updateUIState_fn).call(this, false);
        }
        reset() {
          this.pageNumber = 0;
          this.pageLabel = null;
          this.hasPageLabels = false;
          this.pagesCount = 0;
          this.pageScaleValue = _ui_utils.DEFAULT_SCALE_VALUE;
          this.pageScale = _ui_utils.DEFAULT_SCALE;
          __privateMethod(this, _Toolbar_instances, updateUIState_fn).call(this, true);
          this.updateLoadingIndicatorState();
          this.eventBus.dispatch("toolbarreset", {
            source: this
          });
        }
        updateLoadingIndicatorState(loading = false) {
          const {
            pageNumber
          } = this.items;
          pageNumber.classList.toggle(PAGE_NUMBER_LOADING_INDICATOR, loading);
        }
      }
      _wasLocalized = new WeakMap();
      _Toolbar_instances = new WeakSet();
      bindListeners_fn = function(options) {
        const {
          pageNumber,
          scaleSelect
        } = this.items;
        const self = this;
        for (const {
          element,
          eventName,
          eventDetails
        } of this.buttons) {
          element.addEventListener("click", (evt) => {
            if (eventName !== null) {
              const details = {
                source: this
              };
              if (eventDetails) {
                for (const property in eventDetails) {
                  details[property] = eventDetails[property];
                }
              }
              this.eventBus.dispatch(eventName, details);
            }
          });
        }
        pageNumber.addEventListener("click", function() {
          this.select();
        });
        pageNumber.addEventListener("change", function() {
          self.eventBus.dispatch("pagenumberchanged", {
            source: self,
            value: this.value
          });
        });
        scaleSelect.addEventListener("change", function() {
          if (this.value === "custom") {
            return;
          }
          self.eventBus.dispatch("scalechanged", {
            source: self,
            value: this.value
          });
        });
        scaleSelect.addEventListener("click", function(evt) {
          const target = evt.target;
          if (this.value === self.pageScaleValue && target.tagName.toUpperCase() === "OPTION") {
            this.blur();
          }
        });
        scaleSelect.oncontextmenu = _ui_utils.noContextMenuHandler;
        this.eventBus._on("localized", () => {
          __privateSet(this, _wasLocalized, true);
          __privateMethod(this, _Toolbar_instances, adjustScaleWidth_fn).call(this);
          __privateMethod(this, _Toolbar_instances, updateUIState_fn).call(this, true);
        });
        __privateMethod(this, _Toolbar_instances, bindEditorToolsListener_fn).call(this, options);
      };
      bindEditorToolsListener_fn = function({
        editorFreeTextButton,
        editorFreeTextParamsToolbar,
        editorInkButton,
        editorInkParamsToolbar
      }) {
        const editorModeChanged = (evt, disableButtons = false) => {
          const editorButtons = [{
            mode: _pdfjsLib.AnnotationEditorType.FREETEXT,
            button: editorFreeTextButton,
            toolbar: editorFreeTextParamsToolbar
          }, {
            mode: _pdfjsLib.AnnotationEditorType.INK,
            button: editorInkButton,
            toolbar: editorInkParamsToolbar
          }];
          for (const {
            mode,
            button,
            toolbar
          } of editorButtons) {
            const checked = mode === evt.mode;
            button.classList.toggle("toggled", checked);
            button.setAttribute("aria-checked", checked);
            button.disabled = disableButtons;
            toolbar == null ? void 0 : toolbar.classList.toggle("hidden", !checked);
          }
        };
        this.eventBus._on("annotationeditormodechanged", editorModeChanged);
        this.eventBus._on("toolbarreset", (evt) => {
          if (evt.source === this) {
            editorModeChanged({
              mode: _pdfjsLib.AnnotationEditorType.NONE
            }, true);
          }
        });
      };
      updateUIState_fn = function(resetNumPages = false) {
        if (!__privateGet(this, _wasLocalized)) {
          return;
        }
        const {
          pageNumber,
          pagesCount,
          pageScaleValue,
          pageScale,
          items
        } = this;
        if (resetNumPages) {
          if (this.hasPageLabels) {
            items.pageNumber.type = "text";
          } else {
            items.pageNumber.type = "number";
            this.l10n.get("of_pages", {
              pagesCount
            }).then((msg) => {
              items.numPages.textContent = msg;
            });
          }
          items.pageNumber.max = pagesCount;
        }
        if (this.hasPageLabels) {
          items.pageNumber.value = this.pageLabel;
          this.l10n.get("page_of_pages", {
            pageNumber,
            pagesCount
          }).then((msg) => {
            items.numPages.textContent = msg;
          });
        } else {
          items.pageNumber.value = pageNumber;
        }
        items.previous.disabled = pageNumber <= 1;
        items.next.disabled = pageNumber >= pagesCount;
        items.zoomOut.disabled = pageScale <= _ui_utils.MIN_SCALE;
        items.zoomIn.disabled = pageScale >= _ui_utils.MAX_SCALE;
        this.l10n.get("page_scale_percent", {
          scale: Math.round(pageScale * 1e4) / 100
        }).then((msg) => {
          let predefinedValueFound = false;
          for (const option of items.scaleSelect.options) {
            if (option.value !== pageScaleValue) {
              option.selected = false;
              continue;
            }
            option.selected = true;
            predefinedValueFound = true;
          }
          if (!predefinedValueFound) {
            items.customScaleOption.textContent = msg;
            items.customScaleOption.selected = true;
          }
        });
      };
      adjustScaleWidth_fn = async function() {
        const {
          items,
          l10n
        } = this;
        const predefinedValuesPromise = Promise.all([l10n.get("page_scale_auto"), l10n.get("page_scale_actual"), l10n.get("page_scale_fit"), l10n.get("page_scale_width")]);
        await _ui_utils.animationStarted;
        const style = getComputedStyle(items.scaleSelect), scaleSelectContainerWidth = parseInt(style.getPropertyValue("--scale-select-container-width"), 10), scaleSelectOverflow = parseInt(style.getPropertyValue("--scale-select-overflow"), 10);
        const canvas = document.createElement("canvas");
        const ctx = canvas.getContext("2d", {
          alpha: false
        });
        ctx.font = `${style.fontSize} ${style.fontFamily}`;
        let maxWidth = 0;
        for (const predefinedValue of await predefinedValuesPromise) {
          const {
            width
          } = ctx.measureText(predefinedValue);
          if (width > maxWidth) {
            maxWidth = width;
          }
        }
        maxWidth += 2 * scaleSelectOverflow;
        if (maxWidth > scaleSelectContainerWidth) {
          _ui_utils.docStyle.setProperty("--scale-select-container-width", `${maxWidth}px`);
        }
        canvas.width = 0;
        canvas.height = 0;
      };
      exports.Toolbar = Toolbar;
    }),
    /* 41 */
    /***/
    ((__unused_webpack_module, exports) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.ViewHistory = void 0;
      const DEFAULT_VIEW_HISTORY_CACHE_SIZE = 20;
      class ViewHistory {
        constructor(fingerprint, cacheSize = DEFAULT_VIEW_HISTORY_CACHE_SIZE) {
          this.fingerprint = fingerprint;
          this.cacheSize = cacheSize;
          this._initializedPromise = this._readFromStorage().then((databaseStr) => {
            const database = JSON.parse(databaseStr || "{}");
            let index = -1;
            if (!Array.isArray(database.files)) {
              database.files = [];
            } else {
              while (database.files.length >= this.cacheSize) {
                database.files.shift();
              }
              for (let i = 0, ii = database.files.length; i < ii; i++) {
                const branch = database.files[i];
                if (branch.fingerprint === this.fingerprint) {
                  index = i;
                  break;
                }
              }
            }
            if (index === -1) {
              index = database.files.push({
                fingerprint: this.fingerprint
              }) - 1;
            }
            this.file = database.files[index];
            this.database = database;
          });
        }
        async _writeToStorage() {
          const databaseStr = JSON.stringify(this.database);
          localStorage.setItem("pdfjs.history", databaseStr);
        }
        async _readFromStorage() {
          return localStorage.getItem("pdfjs.history");
        }
        async set(name, val) {
          await this._initializedPromise;
          this.file[name] = val;
          return this._writeToStorage();
        }
        async setMultiple(properties) {
          await this._initializedPromise;
          for (const name in properties) {
            this.file[name] = properties[name];
          }
          return this._writeToStorage();
        }
        async get(name, defaultValue) {
          await this._initializedPromise;
          const val = this.file[name];
          return val !== void 0 ? val : defaultValue;
        }
        async getMultiple(properties) {
          await this._initializedPromise;
          const values = /* @__PURE__ */ Object.create(null);
          for (const name in properties) {
            const val = this.file[name];
            values[name] = val !== void 0 ? val : properties[name];
          }
          return values;
        }
      }
      exports.ViewHistory = ViewHistory;
    }),
    /* 42 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.GenericCom = void 0;
      var _app = __webpack_require__2(4);
      var _preferences = __webpack_require__2(43);
      var _download_manager = __webpack_require__2(44);
      var _genericl10n = __webpack_require__2(45);
      var _generic_scripting = __webpack_require__2(47);
      ;
      const GenericCom = {};
      exports.GenericCom = GenericCom;
      class GenericPreferences extends _preferences.BasePreferences {
        async _writeToStorage(prefObj) {
          localStorage.setItem("pdfjs.preferences", JSON.stringify(prefObj));
        }
        async _readFromStorage(prefObj) {
          return JSON.parse(localStorage.getItem("pdfjs.preferences"));
        }
      }
      class GenericExternalServices extends _app.DefaultExternalServices {
        static createDownloadManager(options) {
          return new _download_manager.DownloadManager();
        }
        static createPreferences() {
          return new GenericPreferences();
        }
        static createL10n({
          locale = "en-US"
        }) {
          return new _genericl10n.GenericL10n(locale);
        }
        static createScripting({
          sandboxBundleSrc
        }) {
          return new _generic_scripting.GenericScripting(sandboxBundleSrc);
        }
      }
      _app.PDFViewerApplication.externalServices = GenericExternalServices;
    }),
    /* 43 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      var _defaults, _prefs, _initializedPromise;
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.BasePreferences = void 0;
      var _app_options = __webpack_require__2(2);
      const _BasePreferences = class _BasePreferences {
        constructor() {
          __privateAdd(this, _defaults, Object.freeze({
            "annotationEditorMode": -1,
            "annotationMode": 2,
            "cursorToolOnLoad": 0,
            "defaultZoomValue": "",
            "disablePageLabels": false,
            "enablePermissions": false,
            "enablePrintAutoRotate": true,
            "enableScripting": true,
            "externalLinkTarget": 0,
            "historyUpdateUrl": false,
            "ignoreDestinationZoom": false,
            "forcePageColors": false,
            "pageColorsBackground": "Canvas",
            "pageColorsForeground": "CanvasText",
            "pdfBugEnabled": false,
            "sidebarViewOnLoad": -1,
            "scrollModeOnLoad": -1,
            "spreadModeOnLoad": -1,
            "textLayerMode": 1,
            "useOnlyCssZoom": false,
            "viewerCssTheme": 0,
            "viewOnLoad": 0,
            "disableAutoFetch": false,
            "disableFontFace": false,
            "disableRange": false,
            "disableStream": false,
            "enableXfa": true,
            "renderer": "canvas"
          }));
          __privateAdd(this, _prefs, /* @__PURE__ */ Object.create(null));
          __privateAdd(this, _initializedPromise, null);
          if (this.constructor === _BasePreferences) {
            throw new Error("Cannot initialize BasePreferences.");
          }
          __privateSet(this, _initializedPromise, this._readFromStorage(__privateGet(this, _defaults)).then((prefs) => {
            for (const name in __privateGet(this, _defaults)) {
              const prefValue = prefs == null ? void 0 : prefs[name];
              if (typeof prefValue === typeof __privateGet(this, _defaults)[name]) {
                __privateGet(this, _prefs)[name] = prefValue;
              }
            }
          }));
        }
        async _writeToStorage(prefObj) {
          throw new Error("Not implemented: _writeToStorage");
        }
        async _readFromStorage(prefObj) {
          throw new Error("Not implemented: _readFromStorage");
        }
        async reset() {
          await __privateGet(this, _initializedPromise);
          const prefs = __privateGet(this, _prefs);
          __privateSet(this, _prefs, /* @__PURE__ */ Object.create(null));
          return this._writeToStorage(__privateGet(this, _defaults)).catch((reason) => {
            __privateSet(this, _prefs, prefs);
            throw reason;
          });
        }
        async set(name, value) {
          await __privateGet(this, _initializedPromise);
          const defaultValue = __privateGet(this, _defaults)[name], prefs = __privateGet(this, _prefs);
          if (defaultValue === void 0) {
            throw new Error(`Set preference: "${name}" is undefined.`);
          } else if (value === void 0) {
            throw new Error("Set preference: no value is specified.");
          }
          const valueType = typeof value, defaultType = typeof defaultValue;
          if (valueType !== defaultType) {
            if (valueType === "number" && defaultType === "string") {
              value = value.toString();
            } else {
              throw new Error(`Set preference: "${value}" is a ${valueType}, expected a ${defaultType}.`);
            }
          } else {
            if (valueType === "number" && !Number.isInteger(value)) {
              throw new Error(`Set preference: "${value}" must be an integer.`);
            }
          }
          __privateGet(this, _prefs)[name] = value;
          return this._writeToStorage(__privateGet(this, _prefs)).catch((reason) => {
            __privateSet(this, _prefs, prefs);
            throw reason;
          });
        }
        async get(name) {
          await __privateGet(this, _initializedPromise);
          const defaultValue = __privateGet(this, _defaults)[name];
          if (defaultValue === void 0) {
            throw new Error(`Get preference: "${name}" is undefined.`);
          }
          return __privateGet(this, _prefs)[name] ?? defaultValue;
        }
        async getAll() {
          await __privateGet(this, _initializedPromise);
          const obj = /* @__PURE__ */ Object.create(null);
          for (const name in __privateGet(this, _defaults)) {
            obj[name] = __privateGet(this, _prefs)[name] ?? __privateGet(this, _defaults)[name];
          }
          return obj;
        }
      };
      _defaults = new WeakMap();
      _prefs = new WeakMap();
      _initializedPromise = new WeakMap();
      let BasePreferences = _BasePreferences;
      exports.BasePreferences = BasePreferences;
    }),
    /* 44 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.DownloadManager = void 0;
      var _pdfjsLib = __webpack_require__2(5);
      ;
      function download(blobUrl, filename) {
        const a = document.createElement("a");
        if (!a.click) {
          throw new Error('DownloadManager: "a.click()" is not supported.');
        }
        a.href = blobUrl;
        a.target = "_parent";
        if ("download" in a) {
          a.download = filename;
        }
        (document.body || document.documentElement).append(a);
        a.click();
        a.remove();
      }
      class DownloadManager {
        constructor() {
          this._openBlobUrls = /* @__PURE__ */ new WeakMap();
        }
        downloadUrl(url, filename) {
          if (!(0, _pdfjsLib.createValidAbsoluteUrl)(url, "http://example.com")) {
            console.error(`downloadUrl - not a valid URL: ${url}`);
            return;
          }
          download(url + "#pdfjs.action=download", filename);
        }
        downloadData(data, filename, contentType) {
          const blobUrl = URL.createObjectURL(new Blob([data], {
            type: contentType
          }));
          download(blobUrl, filename);
        }
        openOrDownloadData(element, data, filename) {
          const isPdfData = (0, _pdfjsLib.isPdfFile)(filename);
          const contentType = isPdfData ? "application/pdf" : "";
          if (isPdfData) {
            let blobUrl = this._openBlobUrls.get(element);
            if (!blobUrl) {
              blobUrl = URL.createObjectURL(new Blob([data], {
                type: contentType
              }));
              this._openBlobUrls.set(element, blobUrl);
            }
            let viewerUrl;
            viewerUrl = "?file=" + encodeURIComponent(blobUrl + "#" + filename);
            try {
              window.open(viewerUrl);
              return true;
            } catch (ex) {
              console.error(`openOrDownloadData: ${ex}`);
              URL.revokeObjectURL(blobUrl);
              this._openBlobUrls.delete(element);
            }
          }
          this.downloadData(data, filename, contentType);
          return false;
        }
        download(blob, url, filename) {
          const blobUrl = URL.createObjectURL(blob);
          download(blobUrl, filename);
        }
      }
      exports.DownloadManager = DownloadManager;
    }),
    /* 45 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.GenericL10n = void 0;
      __webpack_require__2(46);
      var _l10n_utils = __webpack_require__2(31);
      const webL10n = document.webL10n;
      class GenericL10n {
        constructor(lang) {
          this._lang = lang;
          this._ready = new Promise((resolve, reject) => {
            webL10n.setLanguage((0, _l10n_utils.fixupLangCode)(lang), () => {
              resolve(webL10n);
            });
          });
        }
        async getLanguage() {
          const l10n = await this._ready;
          return l10n.getLanguage();
        }
        async getDirection() {
          const l10n = await this._ready;
          return l10n.getDirection();
        }
        async get(key, args = null, fallback = (0, _l10n_utils.getL10nFallback)(key, args)) {
          const l10n = await this._ready;
          return l10n.get(key, args, fallback);
        }
        async translate(element) {
          const l10n = await this._ready;
          return l10n.translate(element);
        }
      }
      exports.GenericL10n = GenericL10n;
    }),
    /* 46 */
    /***/
    (() => {
      document.webL10n = (function(window2, document2, undefined2) {
        var gL10nData = {};
        var gTextData = "";
        var gTextProp = "textContent";
        var gLanguage = "";
        var gMacros = {};
        var gReadyState = "loading";
        var gAsyncResourceLoading = true;
        function getL10nResourceLinks() {
          return document2.querySelectorAll('link[type="application/l10n"]');
        }
        function getL10nDictionary() {
          var script = document2.querySelector('script[type="application/l10n"]');
          return script ? JSON.parse(script.innerHTML) : null;
        }
        function getTranslatableChildren(element) {
          return element ? element.querySelectorAll("*[data-l10n-id]") : [];
        }
        function getL10nAttributes(element) {
          if (!element) return {};
          var l10nId = element.getAttribute("data-l10n-id");
          var l10nArgs = element.getAttribute("data-l10n-args");
          var args = {};
          if (l10nArgs) {
            try {
              args = JSON.parse(l10nArgs);
            } catch (e) {
              console.warn("could not parse arguments for #" + l10nId);
            }
          }
          return {
            id: l10nId,
            args
          };
        }
        function xhrLoadText(url, onSuccess, onFailure) {
          onSuccess = onSuccess || function _onSuccess(data) {
          };
          onFailure = onFailure || function _onFailure() {
          };
          var xhr = new XMLHttpRequest();
          xhr.open("GET", url, gAsyncResourceLoading);
          if (xhr.overrideMimeType) {
            xhr.overrideMimeType("text/plain; charset=utf-8");
          }
          xhr.onreadystatechange = function() {
            if (xhr.readyState == 4) {
              if (xhr.status == 200 || xhr.status === 0) {
                onSuccess(xhr.responseText);
              } else {
                onFailure();
              }
            }
          };
          xhr.onerror = onFailure;
          xhr.ontimeout = onFailure;
          try {
            xhr.send(null);
          } catch (e) {
            onFailure();
          }
        }
        function parseResource(href, lang, successCallback, failureCallback) {
          var baseURL = href.replace(/[^\/]*$/, "") || "./";
          function evalString(text) {
            if (text.lastIndexOf("\\") < 0) return text;
            return text.replace(/\\\\/g, "\\").replace(/\\n/g, "\n").replace(/\\r/g, "\r").replace(/\\t/g, "	").replace(/\\b/g, "\b").replace(/\\f/g, "\f").replace(/\\{/g, "{").replace(/\\}/g, "}").replace(/\\"/g, '"').replace(/\\'/g, "'");
          }
          function parseProperties(text, parsedPropertiesCallback) {
            var dictionary = {};
            var reBlank = /^\s*|\s*$/;
            var reComment = /^\s*#|^\s*$/;
            var reSection = /^\s*\[(.*)\]\s*$/;
            var reImport = /^\s*@import\s+url\((.*)\)\s*$/i;
            var reSplit = /^([^=\s]*)\s*=\s*(.+)$/;
            function parseRawLines(rawText, extendedSyntax, parsedRawLinesCallback) {
              var entries = rawText.replace(reBlank, "").split(/[\r\n]+/);
              var currentLang = "*";
              var genericLang = lang.split("-", 1)[0];
              var skipLang = false;
              var match = "";
              function nextEntry() {
                while (true) {
                  if (!entries.length) {
                    parsedRawLinesCallback();
                    return;
                  }
                  var line = entries.shift();
                  if (reComment.test(line)) continue;
                  if (extendedSyntax) {
                    match = reSection.exec(line);
                    if (match) {
                      currentLang = match[1].toLowerCase();
                      skipLang = currentLang !== "*" && currentLang !== lang && currentLang !== genericLang;
                      continue;
                    } else if (skipLang) {
                      continue;
                    }
                    match = reImport.exec(line);
                    if (match) {
                      loadImport(baseURL + match[1], nextEntry);
                      return;
                    }
                  }
                  var tmp = line.match(reSplit);
                  if (tmp && tmp.length == 3) {
                    dictionary[tmp[1]] = evalString(tmp[2]);
                  }
                }
              }
              nextEntry();
            }
            function loadImport(url, callback) {
              xhrLoadText(url, function(content) {
                parseRawLines(content, false, callback);
              }, function() {
                console.warn(url + " not found.");
                callback();
              });
            }
            parseRawLines(text, true, function() {
              parsedPropertiesCallback(dictionary);
            });
          }
          xhrLoadText(href, function(response) {
            gTextData += response;
            parseProperties(response, function(data) {
              for (var key in data) {
                var id, prop, index = key.lastIndexOf(".");
                if (index > 0) {
                  id = key.substring(0, index);
                  prop = key.substring(index + 1);
                } else {
                  id = key;
                  prop = gTextProp;
                }
                if (!gL10nData[id]) {
                  gL10nData[id] = {};
                }
                gL10nData[id][prop] = data[key];
              }
              if (successCallback) {
                successCallback();
              }
            });
          }, failureCallback);
        }
        function loadLocale(lang, callback) {
          if (lang) {
            lang = lang.toLowerCase();
          }
          callback = callback || function _callback() {
          };
          clear();
          gLanguage = lang;
          var langLinks = getL10nResourceLinks();
          var langCount = langLinks.length;
          if (langCount === 0) {
            var dict = getL10nDictionary();
            if (dict && dict.locales && dict.default_locale) {
              console.log("using the embedded JSON directory, early way out");
              gL10nData = dict.locales[lang];
              if (!gL10nData) {
                var defaultLocale = dict.default_locale.toLowerCase();
                for (var anyCaseLang in dict.locales) {
                  anyCaseLang = anyCaseLang.toLowerCase();
                  if (anyCaseLang === lang) {
                    gL10nData = dict.locales[lang];
                    break;
                  } else if (anyCaseLang === defaultLocale) {
                    gL10nData = dict.locales[defaultLocale];
                  }
                }
              }
              callback();
            } else {
              console.log("no resource to load, early way out");
            }
            gReadyState = "complete";
            return;
          }
          var onResourceLoaded = null;
          var gResourceCount = 0;
          onResourceLoaded = function() {
            gResourceCount++;
            if (gResourceCount >= langCount) {
              callback();
              gReadyState = "complete";
            }
          };
          function L10nResourceLink(link) {
            var href = link.href;
            this.load = function(lang2, callback2) {
              parseResource(href, lang2, callback2, function() {
                console.warn(href + " not found.");
                console.warn('"' + lang2 + '" resource not found');
                gLanguage = "";
                callback2();
              });
            };
          }
          for (var i = 0; i < langCount; i++) {
            var resource = new L10nResourceLink(langLinks[i]);
            resource.load(lang, onResourceLoaded);
          }
        }
        function clear() {
          gL10nData = {};
          gTextData = "";
          gLanguage = "";
        }
        function getPluralRules(lang) {
          var locales2rules = {
            "af": 3,
            "ak": 4,
            "am": 4,
            "ar": 1,
            "asa": 3,
            "az": 0,
            "be": 11,
            "bem": 3,
            "bez": 3,
            "bg": 3,
            "bh": 4,
            "bm": 0,
            "bn": 3,
            "bo": 0,
            "br": 20,
            "brx": 3,
            "bs": 11,
            "ca": 3,
            "cgg": 3,
            "chr": 3,
            "cs": 12,
            "cy": 17,
            "da": 3,
            "de": 3,
            "dv": 3,
            "dz": 0,
            "ee": 3,
            "el": 3,
            "en": 3,
            "eo": 3,
            "es": 3,
            "et": 3,
            "eu": 3,
            "fa": 0,
            "ff": 5,
            "fi": 3,
            "fil": 4,
            "fo": 3,
            "fr": 5,
            "fur": 3,
            "fy": 3,
            "ga": 8,
            "gd": 24,
            "gl": 3,
            "gsw": 3,
            "gu": 3,
            "guw": 4,
            "gv": 23,
            "ha": 3,
            "haw": 3,
            "he": 2,
            "hi": 4,
            "hr": 11,
            "hu": 0,
            "id": 0,
            "ig": 0,
            "ii": 0,
            "is": 3,
            "it": 3,
            "iu": 7,
            "ja": 0,
            "jmc": 3,
            "jv": 0,
            "ka": 0,
            "kab": 5,
            "kaj": 3,
            "kcg": 3,
            "kde": 0,
            "kea": 0,
            "kk": 3,
            "kl": 3,
            "km": 0,
            "kn": 0,
            "ko": 0,
            "ksb": 3,
            "ksh": 21,
            "ku": 3,
            "kw": 7,
            "lag": 18,
            "lb": 3,
            "lg": 3,
            "ln": 4,
            "lo": 0,
            "lt": 10,
            "lv": 6,
            "mas": 3,
            "mg": 4,
            "mk": 16,
            "ml": 3,
            "mn": 3,
            "mo": 9,
            "mr": 3,
            "ms": 0,
            "mt": 15,
            "my": 0,
            "nah": 3,
            "naq": 7,
            "nb": 3,
            "nd": 3,
            "ne": 3,
            "nl": 3,
            "nn": 3,
            "no": 3,
            "nr": 3,
            "nso": 4,
            "ny": 3,
            "nyn": 3,
            "om": 3,
            "or": 3,
            "pa": 3,
            "pap": 3,
            "pl": 13,
            "ps": 3,
            "pt": 3,
            "rm": 3,
            "ro": 9,
            "rof": 3,
            "ru": 11,
            "rwk": 3,
            "sah": 0,
            "saq": 3,
            "se": 7,
            "seh": 3,
            "ses": 0,
            "sg": 0,
            "sh": 11,
            "shi": 19,
            "sk": 12,
            "sl": 14,
            "sma": 7,
            "smi": 7,
            "smj": 7,
            "smn": 7,
            "sms": 7,
            "sn": 3,
            "so": 3,
            "sq": 3,
            "sr": 11,
            "ss": 3,
            "ssy": 3,
            "st": 3,
            "sv": 3,
            "sw": 3,
            "syr": 3,
            "ta": 3,
            "te": 3,
            "teo": 3,
            "th": 0,
            "ti": 4,
            "tig": 3,
            "tk": 3,
            "tl": 4,
            "tn": 3,
            "to": 0,
            "tr": 0,
            "ts": 3,
            "tzm": 22,
            "uk": 11,
            "ur": 3,
            "ve": 3,
            "vi": 0,
            "vun": 3,
            "wa": 4,
            "wae": 3,
            "wo": 0,
            "xh": 3,
            "xog": 3,
            "yo": 0,
            "zh": 0,
            "zu": 3
          };
          function isIn(n, list) {
            return list.indexOf(n) !== -1;
          }
          function isBetween(n, start, end) {
            return start <= n && n <= end;
          }
          var pluralRules = {
            "0": function(n) {
              return "other";
            },
            "1": function(n) {
              if (isBetween(n % 100, 3, 10)) return "few";
              if (n === 0) return "zero";
              if (isBetween(n % 100, 11, 99)) return "many";
              if (n == 2) return "two";
              if (n == 1) return "one";
              return "other";
            },
            "2": function(n) {
              if (n !== 0 && n % 10 === 0) return "many";
              if (n == 2) return "two";
              if (n == 1) return "one";
              return "other";
            },
            "3": function(n) {
              if (n == 1) return "one";
              return "other";
            },
            "4": function(n) {
              if (isBetween(n, 0, 1)) return "one";
              return "other";
            },
            "5": function(n) {
              if (isBetween(n, 0, 2) && n != 2) return "one";
              return "other";
            },
            "6": function(n) {
              if (n === 0) return "zero";
              if (n % 10 == 1 && n % 100 != 11) return "one";
              return "other";
            },
            "7": function(n) {
              if (n == 2) return "two";
              if (n == 1) return "one";
              return "other";
            },
            "8": function(n) {
              if (isBetween(n, 3, 6)) return "few";
              if (isBetween(n, 7, 10)) return "many";
              if (n == 2) return "two";
              if (n == 1) return "one";
              return "other";
            },
            "9": function(n) {
              if (n === 0 || n != 1 && isBetween(n % 100, 1, 19)) return "few";
              if (n == 1) return "one";
              return "other";
            },
            "10": function(n) {
              if (isBetween(n % 10, 2, 9) && !isBetween(n % 100, 11, 19)) return "few";
              if (n % 10 == 1 && !isBetween(n % 100, 11, 19)) return "one";
              return "other";
            },
            "11": function(n) {
              if (isBetween(n % 10, 2, 4) && !isBetween(n % 100, 12, 14)) return "few";
              if (n % 10 === 0 || isBetween(n % 10, 5, 9) || isBetween(n % 100, 11, 14)) return "many";
              if (n % 10 == 1 && n % 100 != 11) return "one";
              return "other";
            },
            "12": function(n) {
              if (isBetween(n, 2, 4)) return "few";
              if (n == 1) return "one";
              return "other";
            },
            "13": function(n) {
              if (isBetween(n % 10, 2, 4) && !isBetween(n % 100, 12, 14)) return "few";
              if (n != 1 && isBetween(n % 10, 0, 1) || isBetween(n % 10, 5, 9) || isBetween(n % 100, 12, 14)) return "many";
              if (n == 1) return "one";
              return "other";
            },
            "14": function(n) {
              if (isBetween(n % 100, 3, 4)) return "few";
              if (n % 100 == 2) return "two";
              if (n % 100 == 1) return "one";
              return "other";
            },
            "15": function(n) {
              if (n === 0 || isBetween(n % 100, 2, 10)) return "few";
              if (isBetween(n % 100, 11, 19)) return "many";
              if (n == 1) return "one";
              return "other";
            },
            "16": function(n) {
              if (n % 10 == 1 && n != 11) return "one";
              return "other";
            },
            "17": function(n) {
              if (n == 3) return "few";
              if (n === 0) return "zero";
              if (n == 6) return "many";
              if (n == 2) return "two";
              if (n == 1) return "one";
              return "other";
            },
            "18": function(n) {
              if (n === 0) return "zero";
              if (isBetween(n, 0, 2) && n !== 0 && n != 2) return "one";
              return "other";
            },
            "19": function(n) {
              if (isBetween(n, 2, 10)) return "few";
              if (isBetween(n, 0, 1)) return "one";
              return "other";
            },
            "20": function(n) {
              if ((isBetween(n % 10, 3, 4) || n % 10 == 9) && !(isBetween(n % 100, 10, 19) || isBetween(n % 100, 70, 79) || isBetween(n % 100, 90, 99))) return "few";
              if (n % 1e6 === 0 && n !== 0) return "many";
              if (n % 10 == 2 && !isIn(n % 100, [12, 72, 92])) return "two";
              if (n % 10 == 1 && !isIn(n % 100, [11, 71, 91])) return "one";
              return "other";
            },
            "21": function(n) {
              if (n === 0) return "zero";
              if (n == 1) return "one";
              return "other";
            },
            "22": function(n) {
              if (isBetween(n, 0, 1) || isBetween(n, 11, 99)) return "one";
              return "other";
            },
            "23": function(n) {
              if (isBetween(n % 10, 1, 2) || n % 20 === 0) return "one";
              return "other";
            },
            "24": function(n) {
              if (isBetween(n, 3, 10) || isBetween(n, 13, 19)) return "few";
              if (isIn(n, [2, 12])) return "two";
              if (isIn(n, [1, 11])) return "one";
              return "other";
            }
          };
          var index = locales2rules[lang.replace(/-.*$/, "")];
          if (!(index in pluralRules)) {
            console.warn("plural form unknown for [" + lang + "]");
            return function() {
              return "other";
            };
          }
          return pluralRules[index];
        }
        gMacros.plural = function(str, param, key, prop) {
          var n = parseFloat(param);
          if (isNaN(n)) return str;
          if (prop != gTextProp) return str;
          if (!gMacros._pluralRules) {
            gMacros._pluralRules = getPluralRules(gLanguage);
          }
          var index = "[" + gMacros._pluralRules(n) + "]";
          if (n === 0 && key + "[zero]" in gL10nData) {
            str = gL10nData[key + "[zero]"][prop];
          } else if (n == 1 && key + "[one]" in gL10nData) {
            str = gL10nData[key + "[one]"][prop];
          } else if (n == 2 && key + "[two]" in gL10nData) {
            str = gL10nData[key + "[two]"][prop];
          } else if (key + index in gL10nData) {
            str = gL10nData[key + index][prop];
          } else if (key + "[other]" in gL10nData) {
            str = gL10nData[key + "[other]"][prop];
          }
          return str;
        };
        function getL10nData(key, args, fallback) {
          var data = gL10nData[key];
          if (!data) {
            console.warn("#" + key + " is undefined.");
            if (!fallback) {
              return null;
            }
            data = fallback;
          }
          var rv = {};
          for (var prop in data) {
            var str = data[prop];
            str = substIndexes(str, args, key, prop);
            str = substArguments(str, args, key);
            rv[prop] = str;
          }
          return rv;
        }
        function substIndexes(str, args, key, prop) {
          var reIndex = /\{\[\s*([a-zA-Z]+)\(([a-zA-Z]+)\)\s*\]\}/;
          var reMatch = reIndex.exec(str);
          if (!reMatch || !reMatch.length) return str;
          var macroName = reMatch[1];
          var paramName = reMatch[2];
          var param;
          if (args && paramName in args) {
            param = args[paramName];
          } else if (paramName in gL10nData) {
            param = gL10nData[paramName];
          }
          if (macroName in gMacros) {
            var macro = gMacros[macroName];
            str = macro(str, param, key, prop);
          }
          return str;
        }
        function substArguments(str, args, key) {
          var reArgs = /\{\{\s*(.+?)\s*\}\}/g;
          return str.replace(reArgs, function(matched_text, arg) {
            if (args && arg in args) {
              return args[arg];
            }
            if (arg in gL10nData) {
              return gL10nData[arg];
            }
            console.log("argument {{" + arg + "}} for #" + key + " is undefined.");
            return matched_text;
          });
        }
        function translateElement(element) {
          var l10n = getL10nAttributes(element);
          if (!l10n.id) return;
          var data = getL10nData(l10n.id, l10n.args);
          if (!data) {
            console.warn("#" + l10n.id + " is undefined.");
            return;
          }
          if (data[gTextProp]) {
            if (getChildElementCount(element) === 0) {
              element[gTextProp] = data[gTextProp];
            } else {
              var children = element.childNodes;
              var found = false;
              for (var i = 0, l = children.length; i < l; i++) {
                if (children[i].nodeType === 3 && /\S/.test(children[i].nodeValue)) {
                  if (found) {
                    children[i].nodeValue = "";
                  } else {
                    children[i].nodeValue = data[gTextProp];
                    found = true;
                  }
                }
              }
              if (!found) {
                var textNode = document2.createTextNode(data[gTextProp]);
                element.prepend(textNode);
              }
            }
            delete data[gTextProp];
          }
          for (var k in data) {
            element[k] = data[k];
          }
        }
        function getChildElementCount(element) {
          if (element.children) {
            return element.children.length;
          }
          if (typeof element.childElementCount !== "undefined") {
            return element.childElementCount;
          }
          var count = 0;
          for (var i = 0; i < element.childNodes.length; i++) {
            count += element.nodeType === 1 ? 1 : 0;
          }
          return count;
        }
        function translateFragment(element) {
          element = element || document2.documentElement;
          var children = getTranslatableChildren(element);
          var elementCount = children.length;
          for (var i = 0; i < elementCount; i++) {
            translateElement(children[i]);
          }
          translateElement(element);
        }
        return {
          get: function(key, args, fallbackString) {
            var index = key.lastIndexOf(".");
            var prop = gTextProp;
            if (index > 0) {
              prop = key.substring(index + 1);
              key = key.substring(0, index);
            }
            var fallback;
            if (fallbackString) {
              fallback = {};
              fallback[prop] = fallbackString;
            }
            var data = getL10nData(key, args, fallback);
            if (data && prop in data) {
              return data[prop];
            }
            return "{{" + key + "}}";
          },
          getData: function() {
            return gL10nData;
          },
          getText: function() {
            return gTextData;
          },
          getLanguage: function() {
            return gLanguage;
          },
          setLanguage: function(lang, callback) {
            loadLocale(lang, function() {
              if (callback) callback();
            });
          },
          getDirection: function() {
            var rtlList = ["ar", "he", "fa", "ps", "ur"];
            var shortCode = gLanguage.split("-", 1)[0];
            return rtlList.indexOf(shortCode) >= 0 ? "rtl" : "ltr";
          },
          translate: translateFragment,
          getReadyState: function() {
            return gReadyState;
          },
          ready: function(callback) {
            if (!callback) {
              return;
            } else if (gReadyState == "complete" || gReadyState == "interactive") {
              window2.setTimeout(function() {
                callback();
              });
            } else if (document2.addEventListener) {
              document2.addEventListener("localized", function once() {
                document2.removeEventListener("localized", once);
                callback();
              });
            }
          }
        };
      })(window, document);
    }),
    /* 47 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.GenericScripting = void 0;
      exports.docPropertiesLookup = docPropertiesLookup;
      var _pdfjsLib = __webpack_require__2(5);
      async function docPropertiesLookup(pdfDocument) {
        const url = "", baseUrl = url.split("#")[0];
        let {
          info,
          metadata,
          contentDispositionFilename,
          contentLength
        } = await pdfDocument.getMetadata();
        if (!contentLength) {
          const {
            length
          } = await pdfDocument.getDownloadInfo();
          contentLength = length;
        }
        return {
          ...info,
          baseURL: baseUrl,
          filesize: contentLength,
          filename: contentDispositionFilename || (0, _pdfjsLib.getPdfFilenameFromUrl)(url),
          metadata: metadata == null ? void 0 : metadata.getRaw(),
          authors: metadata == null ? void 0 : metadata.get("dc:creator"),
          numPages: pdfDocument.numPages,
          URL: url
        };
      }
      class GenericScripting {
        constructor(sandboxBundleSrc) {
          this._ready = (0, _pdfjsLib.loadScript)(sandboxBundleSrc, true).then(() => {
            return window.pdfjsSandbox.QuickJSSandbox();
          });
        }
        async createSandbox(data) {
          const sandbox = await this._ready;
          sandbox.create(data);
        }
        async dispatchEventInSandbox(event) {
          const sandbox = await this._ready;
          setTimeout(() => sandbox.dispatchEvent(event), 0);
        }
        async destroySandbox() {
          const sandbox = await this._ready;
          sandbox.nukeSandbox();
        }
      }
      exports.GenericScripting = GenericScripting;
    }),
    /* 48 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.PDFPrintService = PDFPrintService;
      var _pdfjsLib = __webpack_require__2(5);
      var _app = __webpack_require__2(4);
      var _print_utils = __webpack_require__2(49);
      let activeService = null;
      let dialog = null;
      let overlayManager = null;
      function renderPage(activeServiceOnEntry, pdfDocument, pageNumber, size, printResolution, optionalContentConfigPromise, printAnnotationStoragePromise) {
        const scratchCanvas = activeService.scratchCanvas;
        const PRINT_UNITS = printResolution / _pdfjsLib.PixelsPerInch.PDF;
        scratchCanvas.width = Math.floor(size.width * PRINT_UNITS);
        scratchCanvas.height = Math.floor(size.height * PRINT_UNITS);
        const ctx = scratchCanvas.getContext("2d");
        ctx.save();
        ctx.fillStyle = "rgb(255, 255, 255)";
        ctx.fillRect(0, 0, scratchCanvas.width, scratchCanvas.height);
        ctx.restore();
        return Promise.all([pdfDocument.getPage(pageNumber), printAnnotationStoragePromise]).then(function([pdfPage, printAnnotationStorage]) {
          const renderContext = {
            canvasContext: ctx,
            transform: [PRINT_UNITS, 0, 0, PRINT_UNITS, 0, 0],
            viewport: pdfPage.getViewport({
              scale: 1,
              rotation: size.rotation
            }),
            intent: "print",
            annotationMode: _pdfjsLib.AnnotationMode.ENABLE_STORAGE,
            optionalContentConfigPromise,
            printAnnotationStorage
          };
          return pdfPage.render(renderContext).promise;
        });
      }
      function PDFPrintService(pdfDocument, pagesOverview, printContainer, printResolution, optionalContentConfigPromise = null, printAnnotationStoragePromise = null, l10n) {
        this.pdfDocument = pdfDocument;
        this.pagesOverview = pagesOverview;
        this.printContainer = printContainer;
        this._printResolution = printResolution || 150;
        this._optionalContentConfigPromise = optionalContentConfigPromise || pdfDocument.getOptionalContentConfig();
        this._printAnnotationStoragePromise = printAnnotationStoragePromise || Promise.resolve();
        this.l10n = l10n;
        this.currentPage = -1;
        this.scratchCanvas = document.createElement("canvas");
      }
      PDFPrintService.prototype = {
        layout() {
          this.throwIfInactive();
          const body = document.querySelector("body");
          body.setAttribute("data-pdfjsprinting", true);
          const hasEqualPageSizes = this.pagesOverview.every(function(size) {
            return size.width === this.pagesOverview[0].width && size.height === this.pagesOverview[0].height;
          }, this);
          if (!hasEqualPageSizes) {
            console.warn("Not all pages have the same size. The printed result may be incorrect!");
          }
          this.pageStyleSheet = document.createElement("style");
          const pageSize = this.pagesOverview[0];
          this.pageStyleSheet.textContent = "@page { size: " + pageSize.width + "pt " + pageSize.height + "pt;}";
          body.append(this.pageStyleSheet);
        },
        destroy() {
          if (activeService !== this) {
            return;
          }
          this.printContainer.textContent = "";
          const body = document.querySelector("body");
          body.removeAttribute("data-pdfjsprinting");
          if (this.pageStyleSheet) {
            this.pageStyleSheet.remove();
            this.pageStyleSheet = null;
          }
          this.scratchCanvas.width = this.scratchCanvas.height = 0;
          this.scratchCanvas = null;
          activeService = null;
          ensureOverlay().then(function() {
            if (overlayManager.active === dialog) {
              overlayManager.close(dialog);
            }
          });
        },
        renderPages() {
          if (this.pdfDocument.isPureXfa) {
            (0, _print_utils.getXfaHtmlForPrinting)(this.printContainer, this.pdfDocument);
            return Promise.resolve();
          }
          const pageCount = this.pagesOverview.length;
          const renderNextPage = (resolve, reject) => {
            this.throwIfInactive();
            if (++this.currentPage >= pageCount) {
              renderProgress(pageCount, pageCount, this.l10n);
              resolve();
              return;
            }
            const index = this.currentPage;
            renderProgress(index, pageCount, this.l10n);
            renderPage(this, this.pdfDocument, index + 1, this.pagesOverview[index], this._printResolution, this._optionalContentConfigPromise, this._printAnnotationStoragePromise).then(this.useRenderedPage.bind(this)).then(function() {
              renderNextPage(resolve, reject);
            }, reject);
          };
          return new Promise(renderNextPage);
        },
        useRenderedPage() {
          this.throwIfInactive();
          const img = document.createElement("img");
          const scratchCanvas = this.scratchCanvas;
          if ("toBlob" in scratchCanvas) {
            scratchCanvas.toBlob(function(blob) {
              img.src = URL.createObjectURL(blob);
            });
          } else {
            img.src = scratchCanvas.toDataURL();
          }
          const wrapper = document.createElement("div");
          wrapper.className = "printedPage";
          wrapper.append(img);
          this.printContainer.append(wrapper);
          return new Promise(function(resolve, reject) {
            img.onload = resolve;
            img.onerror = reject;
          });
        },
        performPrint() {
          this.throwIfInactive();
          return new Promise((resolve) => {
            setTimeout(() => {
              if (!this.active) {
                resolve();
                return;
              }
              print.call(window);
              setTimeout(resolve, 20);
            }, 0);
          });
        },
        get active() {
          return this === activeService;
        },
        throwIfInactive() {
          if (!this.active) {
            throw new Error("This print request was cancelled or completed.");
          }
        }
      };
      const print = window.print;
      window.print = function() {
        if (activeService) {
          console.warn("Ignored window.print() because of a pending print job.");
          return;
        }
        ensureOverlay().then(function() {
          if (activeService) {
            overlayManager.open(dialog);
          }
        });
        try {
          dispatchEvent("beforeprint");
        } finally {
          if (!activeService) {
            console.error("Expected print service to be initialized.");
            ensureOverlay().then(function() {
              if (overlayManager.active === dialog) {
                overlayManager.close(dialog);
              }
            });
            return;
          }
          const activeServiceOnEntry = activeService;
          activeService.renderPages().then(function() {
            return activeServiceOnEntry.performPrint();
          }).catch(function() {
          }).then(function() {
            if (activeServiceOnEntry.active) {
              abort();
            }
          });
        }
      };
      function dispatchEvent(eventType) {
        const event = document.createEvent("CustomEvent");
        event.initCustomEvent(eventType, false, false, "custom");
        window.dispatchEvent(event);
      }
      function abort() {
        if (activeService) {
          activeService.destroy();
          dispatchEvent("afterprint");
        }
      }
      function renderProgress(index, total, l10n) {
        dialog || (dialog = document.getElementById("printServiceDialog"));
        const progress = Math.round(100 * index / total);
        const progressBar = dialog.querySelector("progress");
        const progressPerc = dialog.querySelector(".relative-progress");
        progressBar.value = progress;
        l10n.get("print_progress_percent", {
          progress
        }).then((msg) => {
          progressPerc.textContent = msg;
        });
      }
      window.addEventListener("keydown", function(event) {
        if (event.keyCode === 80 && (event.ctrlKey || event.metaKey) && !event.altKey && (!event.shiftKey || window.chrome || window.opera)) {
          window.print();
          event.preventDefault();
          if (event.stopImmediatePropagation) {
            event.stopImmediatePropagation();
          } else {
            event.stopPropagation();
          }
        }
      }, true);
      if ("onbeforeprint" in window) {
        const stopPropagationIfNeeded = function(event) {
          if (event.detail !== "custom" && event.stopImmediatePropagation) {
            event.stopImmediatePropagation();
          }
        };
        window.addEventListener("beforeprint", stopPropagationIfNeeded);
        window.addEventListener("afterprint", stopPropagationIfNeeded);
      }
      let overlayPromise;
      function ensureOverlay() {
        if (!overlayPromise) {
          overlayManager = _app.PDFViewerApplication.overlayManager;
          if (!overlayManager) {
            throw new Error("The overlay manager has not yet been initialized.");
          }
          dialog || (dialog = document.getElementById("printServiceDialog"));
          overlayPromise = overlayManager.register(dialog, true);
          document.getElementById("printCancel").onclick = abort;
          dialog.addEventListener("close", abort);
        }
        return overlayPromise;
      }
      _app.PDFPrintServiceFactory.instance = {
        supportsPrinting: true,
        createPrintService(pdfDocument, pagesOverview, printContainer, printResolution, optionalContentConfigPromise, printAnnotationStoragePromise, l10n) {
          if (activeService) {
            throw new Error("The print service is created and active.");
          }
          activeService = new PDFPrintService(pdfDocument, pagesOverview, printContainer, printResolution, optionalContentConfigPromise, printAnnotationStoragePromise, l10n);
          return activeService;
        }
      };
    }),
    /* 49 */
    /***/
    ((__unused_webpack_module, exports, __webpack_require__2) => {
      Object.defineProperty(exports, "__esModule", {
        value: true
      });
      exports.getXfaHtmlForPrinting = getXfaHtmlForPrinting;
      var _pdfjsLib = __webpack_require__2(5);
      var _pdf_link_service = __webpack_require__2(3);
      var _xfa_layer_builder = __webpack_require__2(38);
      function getXfaHtmlForPrinting(printContainer, pdfDocument) {
        const xfaHtml = pdfDocument.allXfaHtml;
        const linkService = new _pdf_link_service.SimpleLinkService();
        const scale = Math.round(_pdfjsLib.PixelsPerInch.PDF_TO_CSS_UNITS * 100) / 100;
        for (const xfaPage of xfaHtml.children) {
          const page = document.createElement("div");
          page.className = "xfaPrintedPage";
          printContainer.append(page);
          const builder = new _xfa_layer_builder.XfaLayerBuilder({
            pageDiv: page,
            pdfPage: null,
            annotationStorage: pdfDocument.annotationStorage,
            linkService,
            xfaHtml: xfaPage
          });
          const viewport = (0, _pdfjsLib.getXfaPageViewport)(xfaPage, {
            scale
          });
          builder.render(viewport, "print");
        }
      }
    })
    /******/
  ];
  var __webpack_module_cache__ = {};
  function __webpack_require__(moduleId) {
    var cachedModule = __webpack_module_cache__[moduleId];
    if (cachedModule !== void 0) {
      return cachedModule.exports;
    }
    var module = __webpack_module_cache__[moduleId] = {
      /******/
      // no module.id needed
      /******/
      // no module.loaded needed
      /******/
      exports: {}
      /******/
    };
    __webpack_modules__[moduleId](module, module.exports, __webpack_require__);
    return module.exports;
  }
  var __webpack_exports__ = {};
  (() => {
    var _a;
    var exports = __webpack_exports__;
    Object.defineProperty(exports, "__esModule", {
      value: true
    });
    Object.defineProperty(exports, "PDFViewerApplication", {
      enumerable: true,
      get: function() {
        return _app.PDFViewerApplication;
      }
    });
    exports.PDFViewerApplicationConstants = void 0;
    Object.defineProperty(exports, "PDFViewerApplicationOptions", {
      enumerable: true,
      get: function() {
        return _app_options.AppOptions;
      }
    });
    var _ui_utils = __webpack_require__(1);
    var _app_options = __webpack_require__(2);
    var _pdf_link_service = __webpack_require__(3);
    var _app = __webpack_require__(4);
    const pdfjsVersion = "2.16.105";
    const pdfjsBuild = "172ccdbe5";
    const AppConstants = {
      LinkTarget: _pdf_link_service.LinkTarget,
      RenderingStates: _ui_utils.RenderingStates,
      ScrollMode: _ui_utils.ScrollMode,
      SpreadMode: _ui_utils.SpreadMode
    };
    exports.PDFViewerApplicationConstants = AppConstants;
    window.PDFViewerApplication = _app.PDFViewerApplication;
    window.PDFViewerApplicationConstants = AppConstants;
    window.PDFViewerApplicationOptions = _app_options.AppOptions;
    ;
    ;
    {
      __webpack_require__(42);
    }
    ;
    {
      __webpack_require__(48);
    }
    function getViewerConfiguration() {
      let errorWrapper = null;
      errorWrapper = {
        container: document.getElementById("errorWrapper"),
        errorMessage: document.getElementById("errorMessage"),
        closeButton: document.getElementById("errorClose"),
        errorMoreInfo: document.getElementById("errorMoreInfo"),
        moreInfoButton: document.getElementById("errorShowMore"),
        lessInfoButton: document.getElementById("errorShowLess")
      };
      return {
        appContainer: document.body,
        mainContainer: document.getElementById("viewerContainer"),
        viewerContainer: document.getElementById("viewer"),
        toolbar: {
          container: document.getElementById("toolbarViewer"),
          numPages: document.getElementById("numPages"),
          pageNumber: document.getElementById("pageNumber"),
          scaleSelect: document.getElementById("scaleSelect"),
          customScaleOption: document.getElementById("customScaleOption"),
          previous: document.getElementById("previous"),
          next: document.getElementById("next"),
          zoomIn: document.getElementById("zoomIn"),
          zoomOut: document.getElementById("zoomOut"),
          viewFind: document.getElementById("viewFind"),
          openFile: document.getElementById("openFile"),
          print: document.getElementById("print"),
          editorFreeTextButton: document.getElementById("editorFreeText"),
          editorFreeTextParamsToolbar: document.getElementById("editorFreeTextParamsToolbar"),
          editorInkButton: document.getElementById("editorInk"),
          editorInkParamsToolbar: document.getElementById("editorInkParamsToolbar"),
          presentationModeButton: document.getElementById("presentationMode"),
          download: document.getElementById("download"),
          viewBookmark: document.getElementById("viewBookmark")
        },
        secondaryToolbar: {
          toolbar: document.getElementById("secondaryToolbar"),
          toggleButton: document.getElementById("secondaryToolbarToggle"),
          presentationModeButton: document.getElementById("secondaryPresentationMode"),
          openFileButton: document.getElementById("secondaryOpenFile"),
          printButton: document.getElementById("secondaryPrint"),
          downloadButton: document.getElementById("secondaryDownload"),
          viewBookmarkButton: document.getElementById("secondaryViewBookmark"),
          firstPageButton: document.getElementById("firstPage"),
          lastPageButton: document.getElementById("lastPage"),
          pageRotateCwButton: document.getElementById("pageRotateCw"),
          pageRotateCcwButton: document.getElementById("pageRotateCcw"),
          cursorSelectToolButton: document.getElementById("cursorSelectTool"),
          cursorHandToolButton: document.getElementById("cursorHandTool"),
          scrollPageButton: document.getElementById("scrollPage"),
          scrollVerticalButton: document.getElementById("scrollVertical"),
          scrollHorizontalButton: document.getElementById("scrollHorizontal"),
          scrollWrappedButton: document.getElementById("scrollWrapped"),
          spreadNoneButton: document.getElementById("spreadNone"),
          spreadOddButton: document.getElementById("spreadOdd"),
          spreadEvenButton: document.getElementById("spreadEven"),
          documentPropertiesButton: document.getElementById("documentProperties")
        },
        sidebar: {
          outerContainer: document.getElementById("outerContainer"),
          sidebarContainer: document.getElementById("sidebarContainer"),
          toggleButton: document.getElementById("sidebarToggle"),
          thumbnailButton: document.getElementById("viewThumbnail"),
          outlineButton: document.getElementById("viewOutline"),
          attachmentsButton: document.getElementById("viewAttachments"),
          layersButton: document.getElementById("viewLayers"),
          thumbnailView: document.getElementById("thumbnailView"),
          outlineView: document.getElementById("outlineView"),
          attachmentsView: document.getElementById("attachmentsView"),
          layersView: document.getElementById("layersView"),
          outlineOptionsContainer: document.getElementById("outlineOptionsContainer"),
          currentOutlineItemButton: document.getElementById("currentOutlineItem")
        },
        sidebarResizer: {
          outerContainer: document.getElementById("outerContainer"),
          resizer: document.getElementById("sidebarResizer")
        },
        findBar: {
          bar: document.getElementById("findbar"),
          toggleButton: document.getElementById("viewFind"),
          findField: document.getElementById("findInput"),
          highlightAllCheckbox: document.getElementById("findHighlightAll"),
          caseSensitiveCheckbox: document.getElementById("findMatchCase"),
          matchDiacriticsCheckbox: document.getElementById("findMatchDiacritics"),
          entireWordCheckbox: document.getElementById("findEntireWord"),
          findMsg: document.getElementById("findMsg"),
          findResultsCount: document.getElementById("findResultsCount"),
          findPreviousButton: document.getElementById("findPrevious"),
          findNextButton: document.getElementById("findNext")
        },
        passwordOverlay: {
          dialog: document.getElementById("passwordDialog"),
          label: document.getElementById("passwordText"),
          input: document.getElementById("password"),
          submitButton: document.getElementById("passwordSubmit"),
          cancelButton: document.getElementById("passwordCancel")
        },
        documentProperties: {
          dialog: document.getElementById("documentPropertiesDialog"),
          closeButton: document.getElementById("documentPropertiesClose"),
          fields: {
            fileName: document.getElementById("fileNameField"),
            fileSize: document.getElementById("fileSizeField"),
            title: document.getElementById("titleField"),
            author: document.getElementById("authorField"),
            subject: document.getElementById("subjectField"),
            keywords: document.getElementById("keywordsField"),
            creationDate: document.getElementById("creationDateField"),
            modificationDate: document.getElementById("modificationDateField"),
            creator: document.getElementById("creatorField"),
            producer: document.getElementById("producerField"),
            version: document.getElementById("versionField"),
            pageCount: document.getElementById("pageCountField"),
            pageSize: document.getElementById("pageSizeField"),
            linearized: document.getElementById("linearizedField")
          }
        },
        annotationEditorParams: {
          editorFreeTextFontSize: document.getElementById("editorFreeTextFontSize"),
          editorFreeTextColor: document.getElementById("editorFreeTextColor"),
          editorInkColor: document.getElementById("editorInkColor"),
          editorInkThickness: document.getElementById("editorInkThickness"),
          editorInkOpacity: document.getElementById("editorInkOpacity")
        },
        errorWrapper,
        printContainer: document.getElementById("printContainer"),
        openFileInput: document.getElementById("fileInput"),
        debuggerScriptPath: "./debugger.js"
      };
    }
    function webViewerLoad() {
      const config = getViewerConfiguration();
      const event = document.createEvent("CustomEvent");
      event.initCustomEvent("webviewerloaded", true, true, {
        source: window
      });
      try {
        parent.document.dispatchEvent(event);
      } catch (ex) {
        console.error(`webviewerloaded: ${ex}`);
        document.dispatchEvent(event);
      }
      _app.PDFViewerApplication.run(config);
    }
    (_a = document.blockUnblockOnload) == null ? void 0 : _a.call(document, true);
    if (document.readyState === "interactive" || document.readyState === "complete") {
      webViewerLoad();
    } else {
      document.addEventListener("DOMContentLoaded", webViewerLoad, true);
    }
  })();
})();
