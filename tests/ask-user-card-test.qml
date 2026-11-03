import QtQuick 2.15
import QtQuick.Window 2.15
import "file:///C:/Users/guanboyu/Documents/MedClaw/components"

Window {
    id: win
    width: 900
    height: 460
    visible: true
    color: "#EEF0F3"

    property var answers: []
    property var skips: []

    AskUserCard {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: 840
        visible: questions.length > 0
        questions: [
            {
                questionId: "q1",
                questionText: "对比当前与既往影像，标记病灶变化时，你希望我怎么处理这两个序列？",
                questionOptions: [
                    { label: "对比当前与既往影像，标记病灶变化" },
                    { label: "审阅分割结果并生成结构化报告" },
                    { label: "启动 AI 解读并生成含关键图注释的报告" },
                    { label: "挂载双视口(轴位 + 冠状位)后再测量" }
                ],
                questionMulti: false,
                questionAllowText: true
            },
            {
                questionId: "q2",
                questionText: "报告里要不要包含测量数值？",
                questionOptions: [
                    { label: "包含 RECIST 1.1 长短径与变化率" },
                    { label: "只给结论，不列数值" }
                ],
                questionMulti: false,
                questionAllowText: true
            }
        ]
        onAnswered: function(id, answer) {
            win.answers = win.answers.concat([id + "=" + answer])
            console.log("ANSWER " + id + " => " + answer)
        }
        onSkipped: function(id) {
            win.skips = win.skips.concat([id])
            console.log("SKIP " + id)
        }
    }

    // 简单的分步脚本：选中选项目 → 发送 → 检查信号
    Timer {
        interval: 800
        running: true
        onTriggered: {
            console.log("STATE options=" + card.activeOptions.length
                        + " page=" + card.currentIndex + "/" + (card.questions.length - 1)
                        + " canSend0=" + card.canSend)
            card.toggleOption("审阅分割结果并生成结构化报告")
            console.log("AFTER_SELECT canSend=" + card.canSend
                        + " selected=" + JSON.stringify(card.activeDraft.selected))
            win.contentItem.grabToImage(function(res) {
                res.saveToFile("C:/Users/guanboyu/Documents/MedClaw/build/askcard-select.png")
            })
            card.submit()
            console.log("AFTER_SUBMIT answers=" + JSON.stringify(win.answers)
                        + " page=" + card.currentIndex)
        }
    }

    Timer {
        interval: 1800
        running: true
        onTriggered: {
            // 第二题：直接关掉（跳过）
            console.log("PAGE2 options=" + card.activeOptions.length
                        + " canSend=" + card.canSend
                        + " title=" + (card.activeQuestion ? card.activeQuestion.questionId : "?"))
            card.skip()
            console.log("AFTER_SKIP skips=" + JSON.stringify(win.skips))
        }
    }

    Timer {
        interval: 2600
        running: true
        onTriggered: {
            console.log("RESULT answers=" + JSON.stringify(win.answers)
                        + " skips=" + JSON.stringify(win.skips))
            Qt.quit()
        }
    }
}
