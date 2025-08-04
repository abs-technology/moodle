<?php

class __Mustache_9b7bbf9f2e7925f3091d8ebef2514e50 extends Mustache_Template
{
    private $lambdaHelper;

    public function renderInternal(Mustache_Context $context, $indent = '')
    {
        $this->lambdaHelper = new Mustache_LambdaHelper($this->mustache, $context);
        $buffer = '';

        $buffer .= $indent . '<div class="optionsummary" tabindex="-1" data-region="chooser-option-summary-container">
';
        $buffer .= $indent . '    <div class="content text-start mb-5 px-5 py-4" data-region="chooser-option-summary-content-container">
';
        $buffer .= $indent . '        <div data-region="moodle-net">
';
        $buffer .= $indent . '            <div class="overlay-icon-container z-index-1 d-none" data-region="spinner"></div>
';
        $buffer .= $indent . '            <img class="w-25 mb-4" aria-hidden="true" src="';
        $value = $this->resolveValue($context->find('img'), $context);
        $buffer .= ($value === null ? '' : $value);
        $buffer .= '">
';
        $buffer .= $indent . '            <p>';
        $value = $context->find('str');
        $buffer .= $this->sectionF70a93c4f750a9795773f1773a390c6f($context, $indent, $value);
        $buffer .= '</p>
';
        $buffer .= $indent . '            <p class="w-75 mx-auto mb-1 mt-5">';
        $value = $context->find('str');
        $buffer .= $this->section5ff7c7c6cd22c359a6ed0f341b0dd7cb($context, $indent, $value);
        $buffer .= '</p>
';
        $buffer .= $indent . '            <a class="btn btn-secondary d-block w-75 mx-auto mb-4"
';
        $buffer .= $indent . '               data-action="browse"
';
        $buffer .= $indent . '               href="';
        $value = $this->resolveValue($context->find('generic'), $context);
        $buffer .= ($value === null ? '' : $value);
        $buffer .= '"
';
        $buffer .= $indent . '            >
';
        $buffer .= $indent . '                ';
        $value = $this->resolveValue($context->find('buttonName'), $context);
        $buffer .= ($value === null ? '' : $value);
        $buffer .= '
';
        $buffer .= $indent . '            </a>
';
        $buffer .= $indent . '            <div id="mnet-instance-form-';
        $value = $this->resolveValue($context->find('uniqid'), $context);
        $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
        $buffer .= '" data-region="mnet-form">
';
        $buffer .= $indent . '                <input type="hidden" name="sesskey" value="';
        $value = $this->resolveValue($context->find('sesskey'), $context);
        $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
        $buffer .= '">
';
        $buffer .= $indent . '                <div class="w-75 mx-auto my-3">
';
        $buffer .= $indent . '                    <p class="text-start">';
        $value = $context->find('str');
        $buffer .= $this->sectionEdaa1d58e762ad26bf45a92309e96507($context, $indent, $value);
        $buffer .= '</p>
';
        $buffer .= $indent . '                    <div class="input-group">
';
        $buffer .= $indent . '                        <input type="text"
';
        $buffer .= $indent . '                               class="form-control"
';
        $buffer .= $indent . '                               data-var="mnet-link"
';
        $buffer .= $indent . '                               data-courseid="';
        $value = $this->resolveValue($context->find('courseID'), $context);
        $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
        $buffer .= '"
';
        $buffer .= $indent . '                               data-sectionnum="';
        $value = $this->resolveValue($context->find('sectionnum'), $context);
        $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
        $buffer .= '"
';
        $buffer .= $indent . '                               placeholder="';
        $value = $context->find('str');
        $buffer .= $this->section6d400d789511b9a8983ca7a9c0aa52bc($context, $indent, $value);
        $buffer .= '"
';
        $buffer .= $indent . '                               aria-label="';
        $value = $context->find('str');
        $buffer .= $this->sectionD8483b00847ae0ee4f73a77e3adb2f8d($context, $indent, $value);
        $buffer .= '"
';
        $buffer .= $indent . '                               autocomplete="off"
';
        $buffer .= $indent . '                        >
';
        $buffer .= $indent . '                        <button class="btn btn-secondary"
';
        $buffer .= $indent . '                                data-action="submit" id="button-addon2"
';
        $buffer .= $indent . '                        >
';
        $buffer .= $indent . '                            ';
        $value = $context->find('str');
        $buffer .= $this->section8c983044572c2c53dd841732d7ff18a6($context, $indent, $value);
        $buffer .= '
';
        $buffer .= $indent . '                        </button>
';
        $buffer .= $indent . '                    </div>
';
        $buffer .= $indent . '                    <p class="text-start" aria-live="assertive" data-region="validation-area"></p>
';
        $buffer .= $indent . '                    <p class="text-start">';
        $value = $context->find('str');
        $buffer .= $this->sectionEe917afdbc1dcf0858066cdd58118a04($context, $indent, $value);
        $buffer .= '</p>
';
        $buffer .= $indent . '                </div>
';
        $buffer .= $indent . '            </div>
';
        $buffer .= $indent . '        </div>
';
        $buffer .= $indent . '    </div>
';
        $buffer .= $indent . '</div>
';

        return $buffer;
    }

    private function sectionF70a93c4f750a9795773f1773a390c6f(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' instancedescription, tool_moodlenet ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' instancedescription, tool_moodlenet ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section5ff7c7c6cd22c359a6ed0f341b0dd7cb(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' connectandbrowse, tool_moodlenet ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' connectandbrowse, tool_moodlenet ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionEdaa1d58e762ad26bf45a92309e96507(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'inputhelp, tool_moodlenet';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'inputhelp, tool_moodlenet';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section6d400d789511b9a8983ca7a9c0aa52bc(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' instanceplaceholder, tool_moodlenet ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' instanceplaceholder, tool_moodlenet ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionD8483b00847ae0ee4f73a77e3adb2f8d(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' aria:enterprofile, tool_moodlenet ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' aria:enterprofile, tool_moodlenet ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section8c983044572c2c53dd841732d7ff18a6(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' saveandgo, tool_moodlenet ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' saveandgo, tool_moodlenet ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionEe917afdbc1dcf0858066cdd58118a04(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' forminfo, tool_moodlenet ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' forminfo, tool_moodlenet ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

}
