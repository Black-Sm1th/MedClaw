import { handler } from '../util/vscode';
import './WebUnsupported.css';

export default function WebUnsupported() {
	return (
		<main className="web-unsupported">
			<div className="web-unsupported-content">
				<div className="web-unsupported-message">
					<img
						className="web-unsupported-image"
						src="./unsupported/file_notlook.png"
						alt=""
						aria-hidden="true"
					/>
					<h1 className="web-unsupported-title">文件格式不支持预览</h1>
					<p className="web-unsupported-desc">可使用本地默认软件打开</p>
				</div>
				<button
					type="button"
					className="web-unsupported-button"
					onClick={() => handler.emit('openDefault')}
				>
					本地查看
				</button>
			</div>
		</main>
	);
}
