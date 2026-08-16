// Qt 5.15 WebEngine is based on Chromium 83. Some viewer dependencies use
// newer built-ins, so install the small compatibility layer before they load.
if (typeof Object.hasOwn !== 'function') {
    Object.hasOwn = function (object: object, property: PropertyKey): boolean {
        return Object.prototype.hasOwnProperty.call(Object(object), property);
    };
}

if (typeof (Array.prototype as any).at !== 'function') {
    Object.defineProperty(Array.prototype, 'at', {
        configurable: true,
        writable: true,
        value: function (index: number) {
            const length = this.length >>> 0;
            const normalized = Math.trunc(index) || 0;
            const position = normalized < 0 ? length + normalized : normalized;
            return position < 0 || position >= length ? undefined : this[position];
        },
    });
}

if (typeof (String.prototype as any).at !== 'function') {
    Object.defineProperty(String.prototype, 'at', {
        configurable: true,
        writable: true,
        value: function (index: number) {
            const value = String(this);
            const normalized = Math.trunc(index) || 0;
            const position = normalized < 0 ? value.length + normalized : normalized;
            return position < 0 || position >= value.length ? undefined : value.charAt(position);
        },
    });
}

if (typeof (Array.prototype as any).findLast !== 'function') {
    Object.defineProperty(Array.prototype, 'findLast', {
        configurable: true,
        writable: true,
        value: function (predicate: (value: unknown, index: number, array: unknown[]) => boolean, thisArg?: unknown) {
            for (let index = this.length - 1; index >= 0; index -= 1) {
                if (predicate.call(thisArg, this[index], index, this)) return this[index];
            }
            return undefined;
        },
    });
}

if (typeof (Array.prototype as any).findLastIndex !== 'function') {
    Object.defineProperty(Array.prototype, 'findLastIndex', {
        configurable: true,
        writable: true,
        value: function (predicate: (value: unknown, index: number, array: unknown[]) => boolean, thisArg?: unknown) {
            for (let index = this.length - 1; index >= 0; index -= 1) {
                if (predicate.call(thisArg, this[index], index, this)) return index;
            }
            return -1;
        },
    });
}
