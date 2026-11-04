import QtQuick 2.15
import QtQuick.Window 2.15
import "file:///C:/Users/guanboyu/Documents/MedClaw/components"

Window {
    id: win
    width: 900
    height: 420
    visible: true
    color: "#EEF0F3"

    property int step: 0

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
                questionText: "你想让我做什么？请选择任务类型，或直接描述你的需求。",
                questionOptions: [
                    { label: "文献与情报检索" },
                    { label: "数据分析" },
                    { label: "医学影像处理" },
                    { label: "论文写作" }
                ],
                questionMulti: false,
                questionAllowText: true
            }
        ]
        onAnswered: function(id, answer) { console.log("ANSWER " + id + " => " + answer) }
        onSkipped: function(id) { console.log("SKIP " + id) }
    }

    Timer {
        interval: 700
        running: true
        onTriggered: win.step = 1
    }

    function shot(name, done) {
        win.contentItem.grabToImage(function(res) {
            res.saveToFile("C:/Users/guanboyu/Documents/MedClaw/build/" + name)
            console.log("SHOT " + name)
            done()
        })
    }

    onStepChanged: {
        if (step === 1) {
            console.log("EMPTY skipVisible=" + card.skipVisible
                        + " canSend=" + card.canSend
                        + " text=" + JSON.stringify(card.activeDraft.text))
            shot("askcard-skip-empty.png", function() { win.step = 2 })
        } else if (step === 2) {
            card.setText("帮我做一篇综述")
            win.step = 3
        } else if (step === 3) {
            console.log("TYPED skipVisible=" + card.skipVisible
                        + " canSend=" + card.canSend
                        + " text=" + JSON.stringify(card.activeDraft.text))
            shot("askcard-skip-typed.png", function() { win.step = 4 })
        } else if (step === 4) {
            card.setText("")
            win.step = 5
        } else if (step === 5) {
            console.log("CLEARED skipVisible=" + card.skipVisible)
            shot("askcard-skip-cleared.png", function() { Qt.quit() })
        }
    }
}
